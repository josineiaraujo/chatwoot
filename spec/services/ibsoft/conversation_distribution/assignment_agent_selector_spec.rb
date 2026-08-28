require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AssignmentAgentSelector do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let(:team) { create(:team, account: account, allow_auto_assign: false) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, team: team) }
  let(:first_agent) { create(:user, account: account, role: :agent) }
  let(:second_agent) { create(:user, account: account, role: :agent) }
  let(:allowed_agent_ids) { [first_agent.id, second_agent.id] }
  let(:policy) do
    {
      config: {
        'distribution' => {
          'assignment_order' => 'round_robin',
          'assignment_limit_mode' => 'open_conversations',
          'open_conversation_limit' => 5
        }
      }
    }
  end
  let(:round_robin) { instance_double(AutoAssignment::InboxRoundRobinService) }

  before do
    create(:inbox_member, inbox: inbox, user: first_agent)
    create(:inbox_member, inbox: inbox, user: second_agent)
    create(:team_member, team: team, user: first_agent)
    create(:team_member, team: team, user: second_agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(
      first_agent.id.to_s => 'online',
      second_agent.id.to_s => 'online'
    )
  end

  it 'delegates round-robin selection with only online and allowed agents' do
    allow(round_robin).to receive(:available_agent)
      .with(allowed_agent_ids: match_array(allowed_agent_ids.map(&:to_s)))
      .and_return(first_agent)

    expect(selector.perform).to eq(first_agent)
  end

  it 'does not offer offline, busy or disallowed agents to round robin' do
    disallowed_agent = create(:user, account: account, role: :agent)
    create(:inbox_member, inbox: inbox, user: disallowed_agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(
      first_agent.id.to_s => 'online',
      second_agent.id.to_s => 'busy',
      disallowed_agent.id.to_s => 'online'
    )
    allow(round_robin).to receive(:available_agent)
      .with(allowed_agent_ids: [first_agent.id.to_s])
      .and_return(first_agent)

    expect(selector.perform).to eq(first_agent)
  end

  it 'returns nil without calling round robin when no allowed agent is online' do
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(
      first_agent.id.to_s => 'offline',
      second_agent.id.to_s => 'busy'
    )
    expect(round_robin).not_to receive(:available_agent)

    expect(selector.perform).to be_nil
  end

  it 'removes agents that have reached the simultaneous conversation capacity' do
    policy[:config]['distribution']['open_conversation_limit'] = 1
    create(:conversation, account: account, inbox: inbox, team: team, assignee: first_agent, status: :open)
    allow(round_robin).to receive(:available_agent)
      .with(allowed_agent_ids: [second_agent.id.to_s])
      .and_return(second_agent)

    expect(selector.perform).to eq(second_agent)
  end

  it 'uses the rolling assignment window instead of open conversations when configured' do
    policy[:config]['distribution'].merge!(
      'assignment_limit_mode' => 'assignment_window',
      'fair_distribution_limit' => 1,
      'fair_distribution_window' => 3600
    )
    first_limiter = instance_double(Ibsoft::ConversationDistribution::AssignmentRateLimiter, within_limit?: false)
    second_limiter = instance_double(Ibsoft::ConversationDistribution::AssignmentRateLimiter, within_limit?: true)
    allow(Ibsoft::ConversationDistribution::AssignmentRateLimiter).to receive(:new)
      .with(account: account, conversation: conversation, agent: first_agent, policy: policy)
      .and_return(first_limiter)
    allow(Ibsoft::ConversationDistribution::AssignmentRateLimiter).to receive(:new)
      .with(account: account, conversation: conversation, agent: second_agent, policy: policy)
      .and_return(second_limiter)
    allow(round_robin).to receive(:available_agent)
      .with(allowed_agent_ids: [second_agent.id.to_s])
      .and_return(second_agent)

    expect(selector.perform).to eq(second_agent)
  end

  it 'balances toward the agent with fewer open conversations in the same queue' do
    policy[:config]['distribution']['assignment_order'] = 'balanced'
    create(:conversation, account: account, inbox: inbox, team: team, assignee: first_agent, status: :open)
    allow(round_robin).to receive(:available_agent)
      .with(allowed_agent_ids: [second_agent.id.to_s])
      .and_return(second_agent)

    expect(selector.perform).to eq(second_agent)
  end

  it 'uses round robin as the deterministic tie-breaker for balanced assignment' do
    policy[:config]['distribution']['assignment_order'] = 'balanced'
    create(:conversation, account: account, inbox: inbox, team: team, assignee: first_agent, status: :open)
    create(:conversation, account: account, inbox: inbox, team: team, assignee: second_agent, status: :open)
    allow(round_robin).to receive(:available_agent)
      .with(allowed_agent_ids: match_array(allowed_agent_ids.map(&:to_s)))
      .and_return(second_agent)

    expect(selector.perform).to eq(second_agent)
  end

  it 'does not let conversations from another queue affect balanced counts' do
    policy[:config]['distribution']['assignment_order'] = 'balanced'
    other_inbox = create(:inbox, account: account, enable_auto_assignment: false)
    other_team = create(:team, account: account)
    create(:conversation, account: account, inbox: other_inbox, team: other_team, assignee: first_agent, status: :open)
    allow(round_robin).to receive(:available_agent)
      .with(allowed_agent_ids: match_array(allowed_agent_ids.map(&:to_s)))
      .and_return(first_agent)

    expect(selector.perform).to eq(first_agent)
  end

  def selector
    conversation
    allow(AutoAssignment::InboxRoundRobinService).to receive(:new).with(inbox: inbox).and_return(round_robin)

    described_class.new(
      account: account,
      conversation: conversation,
      allowed_agent_ids: allowed_agent_ids,
      policy: policy
    )
  end
end

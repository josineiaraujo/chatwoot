require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AgentAssignmentClaimer do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account, allow_auto_assign: false) }
  let(:agent) { create(:user, account: account, auto_offline: false) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, team: team) }

  before do
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    account.account_users.find_by!(user: agent).update!(availability: :online)
    conversation.update!(waiting_since: 10.minutes.ago)
    Ibsoft::ConversationDistribution::SourceMarker.new(
      conversation: conversation,
      source: 'manual_team_transfer'
    ).perform
  end

  it 'claims an eligible conversation for the current agent' do
    account.update!(locale: 'pt_BR')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = nil
    perform_enqueued_jobs(only: Conversations::ActivityMessageJob) do
      result = described_class.new(account: account, user: agent, conversation_ids: [conversation.id]).perform
    end

    expect(result[:summary]).to include(requested: 1, assigned: 1, skipped: 0)
    expect(conversation.reload.assignee).to eq(agent)
    expect(conversation.messages.activity.where(content: "Atendimento assumido por #{agent.name} a partir da fila de distribuição.")).to exist

    event = Ibsoft::ConversationDistribution::EventLog.last
    expect(event).to have_attributes(
      conversation_id: conversation.id,
      event_type: 'agent_claim_completed',
      reason: 'claimed_on_agent_entry',
      new_assignee_id: agent.id
    )
    expect(event.metadata.dig('activity_message', 'status')).to eq('enqueued')
  end

  it 'does not claim when real assignment is disabled' do
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(false)

    result = described_class.new(account: account, user: agent, conversation_ids: [conversation.id]).perform

    expect(result[:summary]).to include(requested: 1, assigned: 0, skipped: 1)
    expect(result[:summary][:by_reason]).to include('real_assignment_disabled' => 1)
    expect(conversation.reload.assignee).to be_nil
  end

  it 'does not claim a conversation outside the current agent memberships' do
    outsider = create(:user, account: account, auto_offline: false)
    account.account_users.find_by!(user: outsider).update!(availability: :online)
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account, user: outsider, conversation_ids: [conversation.id]).perform

    expect(result[:summary]).to include(requested: 1, assigned: 0, skipped: 1)
    expect(result[:summary][:by_reason]).to include('not_available_for_agent' => 1)
    expect(conversation.reload.assignee).to be_nil
  end

  it 'does not claim any conversation when required assignments are missing' do
    second_conversation = create_waiting_conversation(waiting_since: 20.minutes.ago)
    create(
      :ibsoft_chathub_account_setting,
      account: account,
      config: {
        agent_entry_assignment: {
          enabled: true,
          required_percentage: 100,
          minimum_required: 1
        }
      }
    )
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account, user: agent, conversation_ids: [conversation.id]).perform

    expect(result[:summary]).to include(requested: 1, assigned: 0, skipped: 1)
    expect(result[:summary][:by_reason]).to include('required_assignments_missing' => 1)
    expect(conversation.reload.assignee).to be_nil
    expect(second_conversation.reload.assignee).to be_nil
  end

  it 'allows the agent to claim all available conversations voluntarily' do
    second_conversation = create_waiting_conversation(waiting_since: 20.minutes.ago)
    third_conversation = create_waiting_conversation(waiting_since: 30.minutes.ago)
    create(
      :ibsoft_chathub_account_setting,
      account: account,
      config: {
        agent_entry_assignment: {
          enabled: true,
          required_percentage: 1,
          minimum_required: 1
        }
      }
    )
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(
      account: account,
      user: agent,
      conversation_ids: [conversation.id, second_conversation.id, third_conversation.id]
    ).perform

    expect(result[:summary]).to include(requested: 3, assigned: 3, skipped: 0)
    assignees = [conversation.reload.assignee, second_conversation.reload.assignee, third_conversation.reload.assignee].compact
    expect(assignees).to contain_exactly(agent, agent, agent)
  end

  def create_waiting_conversation(waiting_since:)
    create(:conversation, account: account, inbox: inbox, team: team, waiting_since: waiting_since).tap do |item|
      Ibsoft::ConversationDistribution::SourceMarker.new(
        conversation: item,
        source: 'manual_team_transfer'
      ).perform
    end
  end
end

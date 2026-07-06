require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AgentAssignmentPreview do
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

  it 'lists waiting conversations available to the current online agent' do
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')

    result = described_class.new(account: account, user: agent).perform

    expect(result[:summary]).to include(available: 1, required: 1)
    expect(result.dig(:candidates, 0)).to include(
      conversation_id: conversation.id,
      display_id: conversation.display_id,
      required: true,
      preselected: true
    )
  end

  it 'does not list conversations when the agent is offline' do
    account.account_users.find_by!(user: agent).update!(availability: :offline)

    result = described_class.new(account: account, user: agent).perform

    expect(result[:summary]).to include(available: 0, required: 0)
    expect(result[:candidates]).to be_empty
  end

  it 'uses the global ChatHub percentage to mark required conversations across the available queue' do
    second_conversation = create(:conversation, account: account, inbox: inbox, team: team)
    second_conversation.update!(waiting_since: 20.minutes.ago)
    Ibsoft::ConversationDistribution::SourceMarker.new(
      conversation: second_conversation,
      source: 'manual_team_transfer'
    ).perform
    create(
      :ibsoft_chathub_account_setting,
      account: account,
      config: {
        agent_entry_assignment: {
          enabled: true,
          required_percentage: 50,
          minimum_required: 1
        }
      }
    )
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account, user: agent).perform

    expect(result[:summary]).to include(available: 2, required: 1, auto_claim: 0)
    expect(result[:agent_entry_assignment]).to include(required_percentage: 50, required_count: 1)
    expect(result[:auto_claim_conversation_ids]).to be_empty
  end

  it 'marks only the required conversations without limiting voluntary selections' do
    second_conversation = create(:conversation, account: account, inbox: inbox, team: team)
    third_conversation = create(:conversation, account: account, inbox: inbox, team: team)
    [second_conversation, third_conversation].each_with_index do |item, index|
      item.update!(waiting_since: (20 + index).minutes.ago)
      Ibsoft::ConversationDistribution::SourceMarker.new(
        conversation: item,
        source: 'manual_team_transfer'
      ).perform
    end
    create(
      :ibsoft_chathub_account_setting,
      account: account,
      config: {
        agent_entry_assignment: {
          enabled: true,
          required_percentage: 50,
          minimum_required: 1
        }
      }
    )
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')

    result = described_class.new(account: account, user: agent).perform

    expect(result[:summary]).to include(available: 3, required: 2)
    expect(result[:candidates].count { |candidate| candidate[:required] }).to eq(2)
  end
end

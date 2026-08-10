require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AutomationHandoffCandidateFinder do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:target_team) { create(:team, account: account, name: 'Suporte') }
  let(:agent_bot) { create(:agent_bot, account: account) }

  before do
    create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
    create(
      :ibsoft_automation_handoff_policy,
      account: account,
      inbox: inbox,
      target_team: target_team,
      stale_after_minutes: 10
    )
  end

  it 'returns pending bot conversations older than the configured idle time' do
    conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      status: :pending,
      assignee_agent_bot: agent_bot,
      last_activity_at: 15.minutes.ago,
      waiting_since: 15.minutes.ago
    )

    result = described_class.new(account: account).perform

    expect(result.pluck(:conversation_id)).to eq([conversation.id])
    expect(result.first).to include(
      display_id: conversation.display_id,
      target_team_id: target_team.id,
      stale_after_minutes: 10,
      automation_signal: 'active_inbox_bot'
    )
    expect(conversation.reload.assignee_agent_bot).to eq(agent_bot)
  end

  it 'ignores conversations that are still inside the idle window' do
    create(:conversation, account: account, inbox: inbox, status: :pending, last_activity_at: 5.minutes.ago)

    expect(described_class.new(account: account).perform).to be_empty
  end

  it 'ignores conversations outside pending status' do
    conversation = create(:conversation, account: account, inbox: inbox, status: :pending, last_activity_at: 15.minutes.ago)
    conversation.update!(status: :open)

    expect(described_class.new(account: account).perform).to be_empty
  end

  it 'ignores conversations already assigned to a human' do
    agent = create(:user, account: account)
    create(
      :conversation,
      account: account,
      inbox: inbox,
      status: :pending,
      assignee: agent,
      last_activity_at: 15.minutes.ago
    )

    expect(described_class.new(account: account).perform).to be_empty
  end

  it 'ignores conversations with a first human reply' do
    create(
      :conversation,
      account: account,
      inbox: inbox,
      status: :pending,
      first_reply_created_at: 12.minutes.ago,
      last_activity_at: 15.minutes.ago
    )

    expect(described_class.new(account: account).perform).to be_empty
  end

  it 'ignores conversations without an automation signal' do
    plain_inbox = create(:inbox, account: account)
    create(
      :ibsoft_automation_handoff_policy,
      account: account,
      inbox: plain_inbox,
      target_team: target_team,
      stale_after_minutes: 10
    )
    create(:conversation, account: account, inbox: plain_inbox, status: :pending, last_activity_at: 15.minutes.ago)

    expect(described_class.new(account: account, inbox_id: plain_inbox.id).perform).to be_empty
  end

  it 'does not return a conversation already handed off after its last activity' do
    conversation = create(:conversation, account: account, inbox: inbox, status: :pending, last_activity_at: 15.minutes.ago)
    create(
      :ibsoft_distribution_event_log,
      account: account,
      inbox: inbox,
      conversation: conversation,
      event_type: 'automation_handoff_completed',
      reason: 'automation_stalled',
      created_at: 5.minutes.ago
    )

    expect(described_class.new(account: account).perform).to be_empty
  end
end

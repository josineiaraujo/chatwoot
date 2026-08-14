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

  it 'returns a pending conversation waiting since the last public bot message' do
    conversation = pending_conversation
    bot_message = create_bot_message(conversation, created_at: 15.minutes.ago)

    result = described_class.new(account: account).perform

    expect(result.pluck(:conversation_id)).to eq([conversation.id])
    expect(result.first).to include(
      display_id: conversation.display_id,
      target_team_id: target_team.id,
      stale_after_minutes: 10,
      timeout_action: 'forward_to_team',
      last_bot_message_id: bot_message.id,
      automation_signal: 'active_inbox_bot'
    )
    expect(result.first[:waited_seconds]).to be >= 15.minutes.to_i
    expect(conversation.reload.assignee_agent_bot).to eq(agent_bot)
  end

  it 'ignores a bot message that is still inside the waiting window' do
    create_bot_message(pending_conversation, created_at: 5.minutes.ago)

    expect(described_class.new(account: account).perform).to be_empty
  end

  it 'restarts the waiting window when the bot sends a newer public message' do
    conversation = pending_conversation
    create_bot_message(conversation, created_at: 20.minutes.ago)
    create_bot_message(conversation, created_at: 2.minutes.ago)

    expect(described_class.new(account: account).perform).to be_empty
  end

  it 'ignores the conversation after the customer replies to the bot' do
    conversation = pending_conversation
    create_bot_message(conversation, created_at: 20.minutes.ago)
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      message_type: :incoming,
      created_at: 15.minutes.ago
    )

    expect(described_class.new(account: account).perform).to be_empty
  end

  it 'ignores the conversation after a public human message' do
    conversation = pending_conversation
    create_bot_message(conversation, created_at: 20.minutes.ago)
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: create(:user, account: account),
      message_type: :outgoing,
      created_at: 15.minutes.ago
    )

    expect(described_class.new(account: account).perform).to be_empty
  end

  it 'does not restart the waiting window for a private note' do
    conversation = pending_conversation
    bot_message = create_bot_message(conversation, created_at: 20.minutes.ago)
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: create(:user, account: account),
      message_type: :outgoing,
      private: true,
      created_at: 2.minutes.ago
    )

    expect(described_class.new(account: account).perform.first).to include(
      conversation_id: conversation.id,
      last_bot_message_id: bot_message.id
    )
  end

  it 'does not restart the waiting window for an activity message' do
    conversation = pending_conversation
    bot_message = create_bot_message(conversation, created_at: 20.minutes.ago)
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      message_type: :activity,
      created_at: 2.minutes.ago
    )

    expect(described_class.new(account: account).perform.first).to include(
      conversation_id: conversation.id,
      last_bot_message_id: bot_message.id
    )
  end

  it 'ignores conversations outside pending status' do
    conversation = pending_conversation
    create_bot_message(conversation, created_at: 15.minutes.ago)
    conversation.update!(status: :open)

    expect(described_class.new(account: account).perform).to be_empty
  end

  it 'ignores conversations already assigned to a human' do
    conversation = pending_conversation(assignee: create(:user, account: account))
    create_bot_message(conversation, created_at: 15.minutes.ago)

    expect(described_class.new(account: account).perform).to be_empty
  end

  it 'ignores conversations with a first human reply' do
    conversation = pending_conversation(first_reply_created_at: 20.minutes.ago)
    create_bot_message(conversation, created_at: 15.minutes.ago)

    expect(described_class.new(account: account).perform).to be_empty
  end

  it 'ignores conversations without a public bot message' do
    pending_conversation

    expect(described_class.new(account: account).perform).to be_empty
  end

  it 'supports close policies without a target team' do
    policy = Ibsoft::ConversationDistribution::AutomationHandoffPolicy.find_by!(account: account, inbox: inbox)
    policy.update!(timeout_action: 'close_conversation', target_team: nil)
    conversation = pending_conversation
    create_bot_message(conversation, created_at: 15.minutes.ago)

    expect(described_class.new(account: account).perform.first).to include(
      conversation_id: conversation.id,
      timeout_action: 'close_conversation',
      target_team_id: nil
    )
  end

  it 'ignores conversations that already have a pending close schedule' do
    policy = Ibsoft::ConversationDistribution::AutomationHandoffPolicy.find_by!(account: account, inbox: inbox)
    policy.update!(
      timeout_action: 'close_conversation',
      target_team: nil,
      close_warning_enabled: true
    )
    conversation = pending_conversation
    bot_message = create_bot_message(conversation, created_at: 15.minutes.ago)
    warning_message = create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      message_type: :template,
      content_attributes: {
        ibsoft_conversation_distribution: { action: 'close_warning' }
      }
    )
    Ibsoft::ConversationDistribution::AutomationCloseSchedule.create!(
      account: account,
      conversation: conversation,
      automation_handoff_policy: policy,
      trigger_message_id: bot_message.id,
      warning_message_id: warning_message.id,
      expected_team_id: conversation.team_id,
      expected_agent_bot_id: conversation.assignee_agent_bot_id,
      expected_policy_updated_at: policy.updated_at,
      close_at: 1.minute.from_now
    )

    expect(described_class.new(account: account).perform).to be_empty
  end

  it 'does not return a conversation already processed after the last bot message' do
    conversation = pending_conversation
    create_bot_message(conversation, created_at: 15.minutes.ago)
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

  private

  def pending_conversation(attributes = {})
    create(
      :conversation,
      {
        account: account,
        inbox: inbox,
        status: :pending,
        assignee_agent_bot: agent_bot
      }.merge(attributes)
    )
  end

  def create_bot_message(conversation, created_at:)
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: agent_bot,
      message_type: :outgoing,
      created_at: created_at
    )
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AutomationWaitingSignal do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending) }
  let(:agent_bot) { create(:agent_bot, account: account) }

  it 'is eligible when the last public message is an old bot response' do
    message = create_message(sender: agent_bot, message_type: :outgoing, created_at: 15.minutes.ago)

    signal = described_class.new(
      conversation: conversation,
      stale_after_minutes: 10,
      expected_message_id: message.id
    )

    expect(signal).to be_eligible
  end

  it 'is not eligible when the expected message changed' do
    old_message = create_message(sender: agent_bot, message_type: :outgoing, created_at: 15.minutes.ago)
    create_message(message_type: :incoming, created_at: 1.minute.ago)

    signal = described_class.new(
      conversation: conversation,
      stale_after_minutes: 10,
      expected_message_id: old_message.id
    )

    expect(signal).not_to be_eligible
  end

  it 'is not eligible without a public message' do
    signal = described_class.new(conversation: conversation, stale_after_minutes: 10)

    expect(signal).not_to be_eligible
  end

  it 'is not eligible while the last bot response is inside the waiting window' do
    create_message(sender: agent_bot, message_type: :outgoing, created_at: 5.minutes.ago)

    signal = described_class.new(conversation: conversation, stale_after_minutes: 10)

    expect(signal).not_to be_eligible
  end

  it 'is not eligible when the last public message came from the customer' do
    create_message(sender: agent_bot, message_type: :outgoing, created_at: 20.minutes.ago)
    create_message(message_type: :incoming, created_at: 15.minutes.ago)

    signal = described_class.new(conversation: conversation, stale_after_minutes: 10)

    expect(signal).not_to be_eligible
  end

  it 'is not eligible when the last public outgoing message came from a human' do
    create_message(
      sender: create(:user, account: account),
      message_type: :outgoing,
      created_at: 15.minutes.ago
    )

    signal = described_class.new(conversation: conversation, stale_after_minutes: 10)

    expect(signal).not_to be_eligible
  end

  it 'ignores newer private notes and activity messages' do
    bot_message = create_message(sender: agent_bot, message_type: :outgoing, created_at: 20.minutes.ago)
    create_message(
      sender: create(:user, account: account),
      message_type: :outgoing,
      private: true,
      created_at: 2.minutes.ago
    )
    create_message(message_type: :activity, created_at: 1.minute.ago)

    signal = described_class.new(
      conversation: conversation,
      stale_after_minutes: 10,
      expected_message_id: bot_message.id
    )

    expect(signal).to be_eligible
  end

  private

  def create_message(attributes = {})
    create(
      :message,
      {
        account: account,
        inbox: inbox,
        conversation: conversation
      }.merge(attributes)
    )
  end
end

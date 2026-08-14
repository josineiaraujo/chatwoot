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

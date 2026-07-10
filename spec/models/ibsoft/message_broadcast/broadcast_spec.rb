require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::Broadcast do
  it 'validates status, source type and conversation mode' do
    broadcast = build(
      :ibsoft_message_broadcast,
      status: 'invalid',
      source_type: 'unknown',
      conversation_mode: 'invalid'
    )

    expect(broadcast).not_to be_valid
    expect(broadcast.errors[:status]).to be_present
    expect(broadcast.errors[:source_type]).to be_present
    expect(broadcast.errors[:conversation_mode]).to be_present
  end

  it 'destroys recipients when the broadcast is removed' do
    broadcast = create(:ibsoft_message_broadcast)
    recipient = create(:ibsoft_message_broadcast_recipient, broadcast: broadcast)

    broadcast.destroy!

    expect(Ibsoft::MessageBroadcast::Recipient.exists?(recipient.id)).to be(false)
  end
end

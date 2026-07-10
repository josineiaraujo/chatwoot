require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::Recipient do
  it 'requires unique external customers per broadcast' do
    recipient = create(:ibsoft_message_broadcast_recipient, external_customer_id: '4797')
    duplicate = build(
      :ibsoft_message_broadcast_recipient,
      broadcast: recipient.broadcast,
      external_customer_id: '4797'
    )

    expect(duplicate).not_to be_valid
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::StatusUpdater do
  let(:broadcast) { create(:ibsoft_message_broadcast, status: 'completed') }
  let(:recipient) do
    create(
      :ibsoft_message_broadcast_recipient,
      broadcast: broadcast,
      status: 'accepted',
      meta_message_id: 'wamid.broadcast-1'
    )
  end

  it 'advances the delivery status and ignores an older webhook afterward' do
    described_class.new(recipient: recipient, status: { status: 'delivered' }).call
    described_class.new(recipient: recipient, status: { status: 'sent' }).call

    expect(recipient.reload.status).to eq('delivered')
    expect(broadcast.reload.status).to eq('completed')
  end

  it 'records a definitive Meta delivery failure' do
    described_class.new(
      recipient: recipient,
      status: {
        status: 'failed',
        errors: [{ code: 13_147, title: 'Message undeliverable' }]
      }
    ).call

    expect(recipient.reload).to have_attributes(
      status: 'failed',
      error_code: '13147',
      error_message: 'Message undeliverable'
    )
    expect(broadcast.reload.status).to eq('failed')
  end
end

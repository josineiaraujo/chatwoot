require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::StatusUpdater do
  let(:delivery) do
    create(
      :ibsoft_external_message_delivery,
      status: 'accepted',
      meta_message_id: 'wamid.external-1'
    )
  end

  it 'advances delivery status and ignores an older webhook afterward' do
    described_class.new(
      delivery: delivery,
      status: { id: 'wamid.external-1', status: 'delivered' }
    ).call
    delivered_at = delivery.reload.delivered_at

    described_class.new(
      delivery: delivery,
      status: { id: 'wamid.external-1', status: 'sent' }
    ).call

    expect(delivery.reload).to have_attributes(
      status: 'delivered',
      delivered_at: delivered_at
    )
  end

  it 'stores a Meta delivery failure' do
    described_class.new(
      delivery: delivery,
      status: {
        id: 'wamid.external-1',
        status: 'failed',
        errors: [{ code: 13_147, title: 'Message undeliverable' }]
      }
    ).call

    expect(delivery.reload).to have_attributes(
      status: 'failed',
      error_code: '13147',
      error_message: 'Message undeliverable'
    )
  end
end

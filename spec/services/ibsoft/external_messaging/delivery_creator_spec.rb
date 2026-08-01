require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::DeliveryCreator do
  let(:endpoint) { create(:ibsoft_external_message_endpoint) }
  let(:attributes) do
    {
      idempotency_key: 'invoice-42',
      request_fingerprint: 'fingerprint',
      recipient: '5575982479788',
      template_name: 'ticket_status_updated',
      template_language: 'en',
      template_type: 'standard',
      template_components: [],
      message_content: 'Hello customer'
    }
  end

  it 'returns the original delivery for an identical repeated request' do
    first = described_class.new(endpoint: endpoint, attributes: attributes).call
    second = described_class.new(endpoint: endpoint, attributes: attributes).call

    expect(first.created).to be(true)
    expect(second.created).to be(false)
    expect(second.delivery).to eq(first.delivery)
    expect(endpoint.deliveries.count).to eq(1)
  end

  it 'rejects reuse of an idempotency key with different content' do
    described_class.new(endpoint: endpoint, attributes: attributes).call

    expect do
      described_class.new(
        endpoint: endpoint,
        attributes: attributes.merge(request_fingerprint: 'different')
      ).call
    end.to raise_error(described_class::IdempotencyConflict)
  end

  it 'creates a canonical order with the opening delivery' do
    result = described_class.new(
      endpoint: endpoint,
      attributes: attributes.merge(
        template_type: 'order',
        order_reference_id: 'invoice-42'
      )
    ).call

    expect(result.delivery.external_order).to have_attributes(
      account_id: endpoint.account_id,
      inbox_id: endpoint.inbox_id,
      reference_id: 'invoice-42',
      order_status: 'pending'
    )
  end

  it 'prevents the same order reference across instances on the same channel' do
    order_attributes = attributes.merge(
      template_type: 'order',
      order_reference_id: 'invoice-42'
    )
    first = described_class.new(endpoint: endpoint, attributes: order_attributes).call
    other_endpoint = create(
      :ibsoft_external_message_endpoint,
      account: endpoint.account,
      inbox: endpoint.inbox
    )

    second = described_class.new(
      endpoint: other_endpoint,
      attributes: order_attributes.merge(idempotency_key: 'other-key')
    ).call

    expect(second).to have_attributes(created: false, delivery: first.delivery)
    expect(
      Ibsoft::ExternalMessaging::Order.where(
        account: endpoint.account,
        inbox: endpoint.inbox,
        reference_id: 'invoice-42'
      ).count
    ).to eq(1)
  end
end

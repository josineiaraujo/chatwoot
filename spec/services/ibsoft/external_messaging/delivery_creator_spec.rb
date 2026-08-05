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
  let(:order_attributes) do
    attributes.merge(
      template_type: 'order',
      order_reference_id: 'invoice-42'
    )
  end

  def create_delivery(attributes_to_create = attributes)
    described_class.new(endpoint: endpoint, attributes: attributes_to_create).call
  end

  it 'returns the original delivery for an identical internal request identity' do
    first = create_delivery
    second = create_delivery

    expect(first.created).to be(true)
    expect(second.created).to be(false)
    expect(second.delivery).to eq(first.delivery)
    expect(endpoint.deliveries.count).to eq(1)
  end

  it 'rejects reuse of an internal identity with different content' do
    create_delivery

    expect do
      create_delivery(attributes.merge(request_fingerprint: 'different'))
    end.to raise_error(described_class::IdempotencyConflict)
  end

  it 'creates a canonical order and links its opening delivery' do
    result = create_delivery(order_attributes)

    expect(result.delivery.external_order).to have_attributes(
      endpoint_id: endpoint.id,
      account_id: endpoint.account_id,
      inbox_id: endpoint.inbox_id,
      reference_id: 'invoice-42',
      order_status: 'pending'
    )
    expect(result.delivery.external_order.opening_delivery).to eq(result.delivery)
  end

  it 'creates a new delivery for a repeated reference in the same instance' do
    first = create_delivery(order_attributes)
    second = create_delivery(
      order_attributes.merge(
        idempotency_key: 'invoice-42-reminder',
        request_fingerprint: 'reminder-fingerprint'
      )
    )

    expect(second.created).to be(true)
    expect(second.delivery).not_to eq(first.delivery)
    expect(second.delivery.external_order).to eq(first.delivery.external_order)
    expect(first.delivery.external_order.reload.deliveries).to contain_exactly(
      first.delivery,
      second.delivery
    )
    expect(
      Ibsoft::ExternalMessaging::Order.where(
        endpoint: endpoint,
        reference_id: 'invoice-42'
      ).count
    ).to eq(1)
  end

  it 'allows another template to reference the same canonical order' do
    first = create_delivery(order_attributes)
    second = create_delivery(
      order_attributes.merge(
        idempotency_key: 'invoice-42-collection',
        request_fingerprint: 'collection-fingerprint',
        template_name: 'invoice_collection'
      )
    )

    expect(second.delivery.external_order).to eq(first.delivery.external_order)
    expect(second.delivery.template_name).to eq('invoice_collection')
  end

  it 'allows the same reference in another instance on the same channel' do
    first = create_delivery(order_attributes)
    other_endpoint = create(
      :ibsoft_external_message_endpoint,
      account: endpoint.account,
      inbox: endpoint.inbox
    )

    second = described_class.new(
      endpoint: other_endpoint,
      attributes: order_attributes
    ).call

    expect(second.created).to be(true)
    expect(second.delivery.external_order).not_to eq(first.delivery.external_order)
    expect(Ibsoft::ExternalMessaging::Order.where(reference_id: 'invoice-42').count).to eq(2)
  end

  it 'rejects a repeated reference when resends are disabled' do
    create_delivery(order_attributes)
    endpoint.update!(allow_order_resends: false)
    resend_attributes = order_attributes.merge(
      idempotency_key: 'invoice-42-second',
      request_fingerprint: 'second-fingerprint'
    )

    expect { create_delivery(resend_attributes) }.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) do |error|
      expect(error).to have_attributes(code: 'order_resend_disabled', http_status: :conflict)
    end
  end

  it 'rejects reuse of a reference for another recipient' do
    create_delivery(order_attributes)
    resend_attributes = order_attributes.merge(
      idempotency_key: 'invoice-42-other-recipient',
      request_fingerprint: 'other-recipient-fingerprint',
      recipient: '5511999999999'
    )

    expect { create_delivery(resend_attributes) }.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) do |error|
      expect(error.code).to eq('order_recipient_mismatch')
    end
  end

  it 'rejects resending an order after payment is captured' do
    first = create_delivery(order_attributes)
    first.delivery.external_order.update!(payment_status: 'captured')
    resend_attributes = order_attributes.merge(
      idempotency_key: 'invoice-42-paid',
      request_fingerprint: 'paid-fingerprint'
    )

    expect { create_delivery(resend_attributes) }.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) do |error|
      expect(error.code).to eq('order_resend_finalized')
    end
  end

  it 'uses an accepted resend when the opening delivery failed' do
    first = create_delivery(order_attributes)
    order = first.delivery.external_order
    first.delivery.update!(status: 'failed', meta_message_id: nil)

    second = create_delivery(
      order_attributes.merge(
        idempotency_key: 'invoice-42-recovery',
        request_fingerprint: 'recovery-fingerprint'
      )
    )
    second.delivery.update!(status: 'accepted', meta_message_id: 'wamid.recovery')

    expect(order.reload).to be_ready_for_updates
  end
end

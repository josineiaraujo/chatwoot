require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::RequestContract do
  let(:endpoint) { create(:ibsoft_external_message_endpoint) }
  let(:payload) do
    {
      recipient: '+55 (75) 98247-9788',
      fields: {
        'template_name' => 'ticket_status_updated',
        'template_language' => 'en',
        'body.name' => 'Josinei',
        'body.ticket_id' => '42'
      }
    }
  end

  def invalid_request
    yield
    raise 'Expected Ibsoft::ExternalMessaging::InvalidRequest'
  rescue Ibsoft::ExternalMessaging::InvalidRequest => e
    e
  end

  it 'builds normalized delivery attributes from semantic fields' do
    result = described_class.new(
      endpoint: endpoint,
      payload: payload,
      idempotency_key: 'order-1'
    ).call

    expect(result).to include(
      recipient: '5575982479788',
      template_name: 'ticket_status_updated',
      template_language: 'en',
      template_type: 'standard',
      idempotency_key: 'order-1'
    )
    expect(result[:template_components]).to include(
      a_hash_including('type' => 'body')
    )
  end

  it 'creates the same fingerprint regardless of semantic field order' do
    reordered = payload.deep_dup
    reordered[:fields] = payload[:fields].to_a.reverse.to_h

    first = described_class.new(endpoint: endpoint, payload: payload, idempotency_key: 'order-1').call
    second = described_class.new(endpoint: endpoint, payload: reordered, idempotency_key: 'order-1').call

    expect(first[:request_fingerprint]).to eq(second[:request_fingerprint])
  end

  it 'rejects invalid recipients' do
    payload[:recipient] = '123'

    error = invalid_request do
      described_class.new(endpoint: endpoint, payload: payload, idempotency_key: 'order-1').call
    end

    expect(error.code).to eq('recipient_invalid')
  end

  it 'uses endpoint defaults for missing PIX fields and removes the key from persisted components', :aggregate_failures do
    endpoint.update!(
      order_pix_merchant_name: 'IBSoft Cloud',
      order_pix_key: '12345678000199',
      order_pix_key_type: 'CNPJ'
    )
    order_payload = {
      recipient: '5575982479788',
      fields: {
        'template_name' => 'invoice_order',
        'template_type' => 'order',
        'order.reference_id' => 'INVOICE-42',
        'order.total' => '64,99',
        'order.item_name' => 'Internet',
        'order.payment.pix.code' => 'PIX-CODE'
      }
    }

    result = described_class.new(
      endpoint: endpoint,
      payload: order_payload,
      idempotency_key: 'invoice-42'
    ).call

    expect(result[:order_pix_key]).to eq('12345678000199')
    expect(result[:template_components].to_json).not_to include('12345678000199')
    expect(result[:message_content]).not_to include('12345678000199')
    expect(result[:template_components].to_json).to include(
      Ibsoft::ExternalMessaging::OrderPixSecret::KEY_REFERENCE
    )
  end

  it 'rejects a PIX order before enqueueing when neither the request nor the endpoint supplies all settings' do
    endpoint.update!(order_pix_merchant_name: 'IBSoft Cloud')
    order_payload = {
      recipient: '5575982479788',
      fields: {
        'template_name' => 'invoice_order',
        'template_type' => 'order',
        'order.reference_id' => 'INVOICE-44',
        'order.total' => '64,99',
        'order.item_name' => 'Internet',
        'order.payment.pix.code' => 'PIX-CODE'
      }
    }

    error = invalid_request do
      described_class.new(
        endpoint: endpoint,
        payload: order_payload,
        idempotency_key: 'invoice-44'
      ).call
    end

    expect(error.code).to eq('field_required')
  end

  it 'uses request PIX values instead of endpoint defaults' do
    endpoint.update!(
      order_pix_merchant_name: 'Default Merchant',
      order_pix_key: 'default@example.com',
      order_pix_key_type: 'EMAIL'
    )
    order_payload = {
      recipient: '5575982479788',
      fields: {
        'template_name' => 'invoice_order',
        'template_type' => 'order',
        'order.reference_id' => 'INVOICE-43',
        'order.total' => '64,99',
        'order.item_name' => 'Internet',
        'order.payment.pix.code' => 'PIX-CODE',
        'order.payment.pix.merchant_name' => 'Request Merchant',
        'order.payment.pix.key' => '12345678000199',
        'order.payment.pix.key_type' => 'CNPJ'
      }
    }

    result = described_class.new(
      endpoint: endpoint,
      payload: order_payload,
      idempotency_key: 'invoice-43'
    ).call

    expect(result[:order_pix_key]).to eq('12345678000199')
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrderDefaultsMerger do
  let(:endpoint) do
    build(
      :ibsoft_external_message_endpoint,
      order_pix_merchant_name: 'IBSoft Cloud',
      order_pix_key: '12345678000199',
      order_pix_key_type: 'CNPJ'
    )
  end

  def merge(fields)
    described_class.new(endpoint: endpoint, fields: fields).call
  end

  it 'fills missing PIX order fields from the endpoint defaults' do
    result = merge(
      'template_type' => 'order',
      'order.payment.pix.code' => 'PIX-CODE'
    )

    expect(result).to include(
      'order.payment.pix.merchant_name' => 'IBSoft Cloud',
      'order.payment.pix.key' => '12345678000199',
      'order.payment.pix.key_type' => 'CNPJ'
    )
  end

  it 'keeps every nonblank value supplied by the external request' do
    result = merge(
      'template_type' => 'order',
      'order.payment.pix.code' => 'PIX-CODE',
      'order.payment.pix.merchant_name' => 'Request Merchant',
      'order.payment.pix.key' => 'request@example.com',
      'order.payment.pix.key_type' => 'EMAIL'
    )

    expect(result).to include(
      'order.payment.pix.merchant_name' => 'Request Merchant',
      'order.payment.pix.key' => 'request@example.com',
      'order.payment.pix.key_type' => 'EMAIL'
    )
  end

  it 'does not inject PIX fields into boleto-only orders' do
    result = merge(
      'template_type' => 'order',
      'order.payment.boleto.digitable_line' => '00190000090000000000'
    )

    expect(result.keys).not_to include(
      'order.payment.pix.merchant_name',
      'order.payment.pix.key',
      'order.payment.pix.key_type'
    )
  end
end

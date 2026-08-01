require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::TemplatePayloadBuilder do
  def build(fields)
    described_class.new(fields: fields).call
  end

  def invalid_request
    yield
    raise 'Expected Ibsoft::ExternalMessaging::InvalidRequest'
  rescue Ibsoft::ExternalMessaging::InvalidRequest => e
    e
  end

  it 'builds named body, document header and interactive buttons' do
    result = build(
      'template_name' => 'invoice_ready',
      'template_language' => 'pt_BR',
      'header_type' => 'document',
      'header_link' => 'https://files.example.com/invoice/42?download=1',
      'header_append_pdf' => 'true',
      'body.customer_name' => 'Maria',
      'body.due_date' => '10/08/2027',
      'button.0.type' => 'url',
      'button.0.value' => '42',
      'button.1.type' => 'copy_code',
      'button.1.value' => 'BARCODE-42'
    )

    expect(result).to include(
      template_name: 'invoice_ready',
      template_language: 'pt_BR',
      template_type: 'standard'
    )
    expect(result[:template_components]).to include(
      a_hash_including(
        'type' => 'header',
        'parameters' => [
          a_hash_including(
            'type' => 'document',
            'document' => a_hash_including(
              'link' => 'https://files.example.com/invoice/42.pdf?download=1'
            )
          )
        ]
      ),
      a_hash_including(
        'type' => 'body',
        'parameters' => [
          { 'type' => 'text', 'parameter_name' => 'customer_name', 'text' => 'Maria' },
          { 'type' => 'text', 'parameter_name' => 'due_date', 'text' => '10/08/2027' }
        ]
      ),
      a_hash_including('type' => 'button', 'sub_type' => 'url', 'index' => 0),
      a_hash_including('type' => 'button', 'sub_type' => 'copy_code', 'index' => 1)
    )
  end

  it 'builds continuous positional body parameters' do
    result = build(
      'template_name' => 'simple_notice',
      'body.1' => 'Primeiro',
      'body.2' => 'Segundo'
    )

    body = result[:template_components].find { |component| component['type'] == 'body' }
    expect(body['parameters']).to eq(
      [
        { 'type' => 'text', 'text' => 'Primeiro' },
        { 'type' => 'text', 'text' => 'Segundo' }
      ]
    )
  end

  it 'normalizes header types and infers known media while building quick replies' do
    document = build(
      'template_name' => 'document_notice',
      'header.type' => 'DOCUMENT',
      'header.link' => 'https://files.example.com/invoice.pdf'
    )
    image = build(
      'template_name' => 'image_notice',
      'header.link' => 'https://files.example.com/banner.webp',
      'button.0.type' => 'quick_reply',
      'button.0.value' => 'OPEN_SUPPORT'
    )

    expect(document[:template_components]).to include(
      a_hash_including(
        'type' => 'header',
        'parameters' => [
          a_hash_including('type' => 'document')
        ]
      )
    )
    expect(image[:template_components]).to include(
      a_hash_including(
        'type' => 'header',
        'parameters' => [
          a_hash_including('type' => 'image')
        ]
      ),
      a_hash_including(
        'type' => 'button',
        'sub_type' => 'quick_reply',
        'parameters' => [{ 'type' => 'payload', 'payload' => 'OPEN_SUPPORT' }]
      )
    )
  end

  it 'builds an order with PIX, boleto, multiple items and expiration' do
    expiration = 1.year.from_now.iso8601
    result = build(
      'template_name' => 'invoice_order',
      'template_type' => 'order',
      'body.customer_name' => 'Maria',
      'order.reference_id' => 'INVOICE-42',
      'order.total' => '64,99',
      'order.payment.pix.code' => 'PIX-CODE',
      'order.payment.pix.merchant_name' => 'IBSoft Cloud',
      'order.payment.pix.key' => '12345678000199',
      'order.payment.pix.key_type' => 'CNPJ',
      'order.payment.boleto.digitable_line' => '00190000090000000000',
      'order.items.0.id' => 'PLAN',
      'order.items.0.name' => 'Plano',
      'order.items.0.amount' => '40,00',
      'order.items.0.quantity' => '1',
      'order.items.1.id' => 'SERVICE',
      'order.items.1.name' => 'Serviço',
      'order.items.1.amount' => '24,99',
      'order.items.1.quantity' => '1',
      'order.expiration_at' => expiration
    )

    expect(result).to include(
      template_type: 'order',
      order_reference_id: 'INVOICE-42'
    )
    order_details = result[:template_components]
                    .find { |component| component['sub_type'] == 'order_details' }
                    .dig('parameters', 0, 'action', 'order_details')
    expect(order_details).to include(
      'reference_id' => 'INVOICE-42',
      'total_amount' => { 'value' => 6499, 'offset' => 100 }
    )
    expect(order_details['payment_settings'].pluck('type')).to eq(
      %w[pix_dynamic_code boleto]
    )
    expect(order_details.dig('order', 'items').size).to eq(2)
  end

  it 'rejects mixed named and positional body variables' do
    error = invalid_request do
      build(
        'template_name' => 'invalid',
        'body.1' => 'Primeiro',
        'body.name' => 'Maria'
      )
    end

    expect(error.code).to eq('body_mixed_variables')
  end

  it 'accepts only the simple and order template types from the public contract' do
    error = invalid_request do
      build(
        'template_name' => 'invalid_type',
        'template_type' => 'standard'
      )
    end

    expect(error.code).to eq('template_type_invalid')
  end

  it 'rejects an order whose values do not match its total' do
    error = invalid_request do
      build(
        'template_name' => 'invoice_order',
        'template_type' => 'order',
        'order.reference_id' => 'INVOICE-42',
        'order.total' => '60,00',
        'order.subtotal' => '50,00',
        'order.payment.boleto.digitable_line' => '00190000090000000000'
      )
    end

    expect(error.code).to eq('order_total_mismatch')
  end

  it 'builds order totals with tax, shipping and discount' do
    result = build(
      'template_name' => 'invoice_order',
      'template_type' => 'order',
      'order.reference_id' => 'INVOICE-43',
      'order.total' => '60,00',
      'order.subtotal' => '50,00',
      'order.tax' => '5,00',
      'order.shipping' => '10,00',
      'order.discount' => '5,00',
      'order.items.0.id' => 'SERVICE',
      'order.items.0.name' => 'Serviço',
      'order.items.0.amount' => '50,00',
      'order.items.0.quantity' => '1',
      'order.payment.boleto.digitable_line' => '00190000090000000000'
    )

    order = result[:template_components]
            .find { |component| component['sub_type'] == 'order_details' }
            .dig('parameters', 0, 'action', 'order_details', 'order')
    expect(order).to include(
      'subtotal' => { 'value' => 5000, 'offset' => 100 },
      'tax' => { 'value' => 500, 'offset' => 100 },
      'shipping' => { 'value' => 1000, 'offset' => 100 },
      'discount' => { 'value' => 500, 'offset' => 100 }
    )
  end

  it 'rejects unsupported fields instead of forwarding them' do
    error = invalid_request do
      build(
        'template_name' => 'invalid',
        'arbitrary_meta_payload' => '{"type":"image"}'
      )
    end

    expect(error.code).to eq('unsupported_field')
  end
end

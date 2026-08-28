require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrderUpdatePayloadBuilder do
  subject(:payload) { described_class.new(update: update).call }

  let(:update) { create(:ibsoft_external_message_order_update) }

  it 'builds the legacy interactive order-status payload from the durable update' do
    update.update!(
      order_status: 'processing',
      payment_status: 'pending',
      payment_timestamp: 1_786_000_000,
      description: 'Pedido em processamento.',
      message_content: 'Estamos processando seu pedido.'
    )

    expect(payload).to include(
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: update.order.recipient,
      type: 'interactive'
    )
    expect(payload.dig(:interactive, :body, :text)).to eq('Estamos processando seu pedido.')
    expect(payload.dig(:interactive, :action, :parameters)).to eq(
      reference_id: update.order.reference_id,
      order: { status: 'processing', description: 'Pedido em processamento.' },
      payment: { status: 'pending', timestamp: 1_786_000_000 }
    )
  end

  it 'builds a template payload with the snapshot and the original order reference' do
    components = [
      {
        type: 'body',
        parameters: [{ type: 'text', text: 'Pagamento confirmado.', parameter_name: 'mensagem_status' }]
      }
    ]
    update.update!(
      delivery_method: 'template',
      template_name: 'atualizacao_fatura',
      template_language: 'pt_BR',
      template_components: components
    )

    expected_payload = {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: update.order.recipient,
      type: 'template',
      template: {
        name: 'atualizacao_fatura',
        language: { policy: 'deterministic', code: 'pt_BR' },
        components: [
          *components,
          {
            type: 'order_status',
            parameters: [
              {
                type: 'order_status',
                order_status: {
                  reference_id: update.order.reference_id,
                  order: { status: 'processing', description: update.description }
                }
              }
            ]
          }
        ]
      }
    }

    expect(payload.deep_stringify_keys).to eq(expected_payload.deep_stringify_keys)
  end

  it 'sends the order reference even when the template has no body variables' do
    update.update!(
      delivery_method: 'template',
      template_name: 'atualizacao_sem_variavel',
      template_language: 'pt_BR',
      template_components: []
    )

    expect(payload.dig(:template, :components)).to eq(
      [
        {
          type: 'order_status',
          parameters: [
            {
              type: 'order_status',
              order_status: {
                reference_id: update.order.reference_id,
                order: { status: 'processing', description: update.description }
              }
            }
          ]
        }
      ]
    )
  end

  it 'keeps payment-only templates independent from order status updates' do
    update.update!(
      order_status: nil,
      payment_status: 'failed',
      delivery_method: 'template',
      template_name: 'falha_pagamento',
      template_language: 'pt_BR',
      template_components: []
    )

    expect(payload.fetch(:template)).not_to have_key(:components)
  end
end

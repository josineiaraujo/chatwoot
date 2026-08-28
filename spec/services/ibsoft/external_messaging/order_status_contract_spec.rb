require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrderStatusContract do
  let(:endpoint) { create(:ibsoft_external_message_endpoint) }

  def contract(fields)
    described_class.new(endpoint: endpoint, fields: fields).call
  end

  it 'normalizes reference, order, and payment aliases' do
    result = contract(
      'id_fatura' => '9388',
      'status_pedido' => 'concluído',
      'status_pagamento' => 'pago',
      'payment_timestamp' => '1783735200'
    )

    expect(result).to include(
      reference_id: '9388',
      order_status: 'completed',
      payment_status: 'captured',
      payment_timestamp: 1_783_735_200
    )
    expect(result[:message_content]).to include('9388')
    expect(result[:description]).to be_present
  end

  it 'supports shortcut statuses for order and payment updates' do
    expect(contract(fatura_id: '1', status: 'parcialmente-enviado')).to include(
      order_status: 'partially_shipped',
      payment_status: nil
    )
    expect(contract(fatura_id: '1', status: 'payment failed')).to include(
      order_status: nil,
      payment_status: 'failed'
    )
  end

  it 'completes the order and captures payment for paid shortcuts' do
    %w[pago paid].each do |status|
      expect(contract(fatura_id: '1', status: status)).to include(
        order_status: 'completed',
        payment_status: 'captured'
      )
    end
  end

  it 'keeps explicit payment status updates independent' do
    expect(contract(fatura_id: '1', payment_status: 'captured')).to include(
      order_status: nil,
      payment_status: 'captured'
    )
  end

  it 'preserves custom message and description values' do
    result = contract(
      reference_id: 'invoice_1',
      order_status: 'shipped',
      message: 'Custom message',
      description: 'Custom description'
    )

    expect(result).to include(
      message_content: 'Custom message',
      description: 'Custom description'
    )
  end

  it 'uses the message configured for the instance when the request omits it' do
    endpoint.update!(
      order_update_messages: {
        order_shipped: 'A ordem {{reference_id}} saiu para entrega.'
      }
    )

    result = contract(reference_id: 'invoice_1', order_status: 'shipped')

    expect(result[:message_content]).to eq('A ordem invoice_1 saiu para entrega.')
  end

  it 'rejects unknown, conflicting, and invalid status fields' do
    expect do
      contract(fatura_id: '1', status: 'pago', unknown: 'value')
    end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) { |error|
      expect(error.code).to eq('unsupported_field')
    }

    expect do
      contract(fatura_id: '1', status: 'pago', payment_status: 'captured')
    end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) { |error|
      expect(error.code).to eq('order_update_status_fields_conflict')
    }

    expect do
      contract(fatura_id: '1', order_status: 'canceled', payment_status: 'captured')
    end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) { |error|
      expect(error.code).to eq('order_update_invalid_combination')
    }
  end
end

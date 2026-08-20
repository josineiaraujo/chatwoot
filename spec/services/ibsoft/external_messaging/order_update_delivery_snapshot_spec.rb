require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrderUpdateDeliverySnapshot do
  let(:endpoint) { create(:ibsoft_external_message_endpoint) }
  let(:command) do
    {
      order_status: 'processing',
      payment_status: nil,
      message_content: 'A fatura está em processamento.'
    }
  end

  def descriptor(name:, body_parameter: nil)
    {
      'id' => name,
      'name' => name,
      'language' => 'pt_BR',
      'parameter_format' => body_parameter ? 'NAMED' : 'POSITIONAL',
      'body_parameter' => body_parameter
    }
  end

  it 'keeps the legacy interactive delivery as the default' do
    snapshot = described_class.new(endpoint: endpoint, command: command).call

    expect(snapshot).to eq(
      delivery_method: 'interactive',
      template_name: nil,
      template_language: nil,
      template_components: []
    )
  end

  it 'snapshots the default template and fills its named body variable' do
    endpoint.update!(
      order_update_delivery_mode: 'template',
      order_update_template_settings: {
        'default' => descriptor(
          name: 'atualizacao_padrao',
          body_parameter: { 'format' => 'named', 'key' => 'mensagem_status' }
        ),
        'overrides' => {}
      }
    )

    snapshot = described_class.new(endpoint: endpoint, command: command).call

    expect(snapshot).to eq(
      delivery_method: 'template',
      template_name: 'atualizacao_padrao',
      template_language: 'pt_BR',
      template_components: [
        {
          type: 'body',
          parameters: [
            {
              type: 'text',
              text: 'A fatura está em processamento.',
              parameter_name: 'mensagem_status'
            }
          ]
        }
      ]
    )
  end

  it 'fills the first positional body variable without a parameter name' do
    endpoint.update!(
      order_update_delivery_mode: 'template',
      order_update_template_settings: {
        'default' => descriptor(
          name: 'atualizacao_posicional',
          body_parameter: { 'format' => 'positional', 'key' => '1' }
        ).merge('parameter_format' => 'POSITIONAL'),
        'overrides' => {}
      }
    )

    snapshot = described_class.new(endpoint: endpoint, command: command).call

    expect(snapshot[:template_components]).to eq(
      [
        {
          type: 'body',
          parameters: [
            {
              type: 'text',
              text: 'A fatura está em processamento.'
            }
          ]
        }
      ]
    )
  end

  it 'uses an event override without adding components to a template with no variables' do
    endpoint.update!(
      order_update_delivery_mode: 'template',
      order_update_template_settings: {
        'default' => descriptor(name: 'atualizacao_padrao'),
        'overrides' => {
          'payment_captured' => descriptor(name: 'pagamento_confirmado')
        }
      }
    )

    snapshot = described_class.new(
      endpoint: endpoint,
      command: command.merge(order_status: nil, payment_status: 'captured')
    ).call

    expect(snapshot).to include(
      delivery_method: 'template',
      template_name: 'pagamento_confirmado',
      template_components: []
    )
  end

  it 'fails before queueing when template delivery has no valid descriptor' do
    endpoint.update_columns( # rubocop:disable Rails/SkipsModelValidations
      order_update_delivery_mode: 'template',
      order_update_template_settings: {}
    )

    expect do
      described_class.new(endpoint: endpoint, command: command).call
    end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) { |error|
      expect(error.code).to eq('order_update_template_not_configured')
    }
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::TemplateParameterBuilder do
  let(:recipient) do
    instance_double(
      Ibsoft::MessageBroadcast::Recipient,
      template_variable_values: {},
      customer_name: 'Cliente Teste',
      primary_phone: '+5571999999999',
      fallback_phone: '+5571888888888',
      phone_used: nil
    )
  end

  def build_params(template_variables)
    broadcast = instance_double(
      Ibsoft::MessageBroadcast::Broadcast,
      template_name: 'aviso_manutencao',
      template_language: 'pt_BR',
      template_variables: template_variables
    )

    described_class.new(broadcast: broadcast, recipient: recipient).call
  end

  it 'keeps positional variables from the header and body independent' do
    result = build_params(
      'header:1' => {
        'type' => 'fixed', 'value' => 'Aviso', 'component_type' => 'HEADER',
        'parameter_key' => '1', 'parameter_type' => 'text'
      },
      'body:1' => {
        'type' => 'fixed', 'value' => 'Cliente Teste', 'component_type' => 'BODY',
        'parameter_key' => '1', 'parameter_type' => 'text'
      }
    )

    expect(result).to eq(
      'name' => 'aviso_manutencao',
      'language' => 'pt_BR',
      'processed_params' => {
        'header' => { '1' => 'Aviso' },
        'body' => { '1' => 'Cliente Teste' }
      }
    )
  end

  it 'maps a media header URL to the enhanced WhatsApp template contract' do
    result = build_params(
      'header_media_url' => {
        'type' => 'fixed',
        'value' => 'https://cdn.example.com/fatura.pdf',
        'component_type' => 'HEADER',
        'parameter_key' => 'media_url',
        'parameter_type' => 'media',
        'media_type' => 'document'
      }
    )

    expect(result.dig('processed_params', 'header')).to eq(
      'media_url' => 'https://cdn.example.com/fatura.pdf',
      'media_type' => 'document'
    )
  end

  it 'produces a Meta document header through the Chatwoot template processor' do
    template_params = build_params(
      'header_media_url' => {
        'type' => 'fixed',
        'value' => 'https://cdn.example.com/fatura.pdf',
        'component_type' => 'HEADER',
        'parameter_key' => 'media_url',
        'parameter_type' => 'media',
        'media_type' => 'document'
      }
    )
    channel = instance_double(
      Channel::Whatsapp,
      message_templates: [
        {
          'name' => 'aviso_manutencao',
          'language' => 'pt_BR',
          'status' => 'APPROVED',
          'parameter_format' => 'POSITIONAL',
          'components' => [{ 'type' => 'HEADER', 'format' => 'DOCUMENT' }]
        }
      ]
    )

    result = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: template_params
    ).call

    expect(result.last).to eq(
      [
        {
          type: 'header',
          parameters: [
            {
              type: 'document',
              document: { link: 'https://cdn.example.com/fatura.pdf' }
            }
          ]
        }
      ]
    )
  end

  it 'preserves dynamic button indexes and builds URL and copy-code parameters' do
    result = build_params(
      'buttons:1:tracking_code' => {
        'type' => 'fixed', 'value' => 'pedido-42', 'component_type' => 'BUTTONS',
        'parameter_key' => 'tracking_code', 'parameter_type' => 'text',
        'button_type' => 'url', 'button_index' => 1
      },
      'buttons:3:copy_code' => {
        'type' => 'fixed', 'value' => 'PIX123', 'component_type' => 'BUTTONS',
        'parameter_key' => 'copy_code', 'parameter_type' => 'text',
        'button_type' => 'copy_code', 'button_index' => 3
      }
    )

    expect(result.dig('processed_params', 'buttons')).to eq(
      [
        { 'type' => 'ibsoft_static_placeholder' },
        { 'type' => 'url', 'parameter' => 'pedido-42' },
        { 'type' => 'ibsoft_static_placeholder' },
        { 'type' => 'copy_code', 'parameter' => 'PIX123' }
      ]
    )
  end

  it 'produces indexed URL and copy-code components through the Chatwoot template processor' do
    template_params = build_params(
      'buttons:1:tracking_code' => {
        'type' => 'fixed', 'value' => 'pedido-42', 'component_type' => 'BUTTONS',
        'button_type' => 'url', 'button_index' => 1
      },
      'buttons:3:copy_code' => {
        'type' => 'fixed', 'value' => 'PIX123', 'component_type' => 'BUTTONS',
        'button_type' => 'copy_code', 'button_index' => 3
      }
    )
    channel = instance_double(
      Channel::Whatsapp,
      message_templates: [
        {
          'name' => 'aviso_manutencao',
          'language' => 'pt_BR',
          'status' => 'APPROVED',
          'parameter_format' => 'POSITIONAL',
          'components' => []
        }
      ]
    )

    result = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: template_params
    ).call

    expect(result.last).to include(
      {
        type: 'button', sub_type: 'url', index: 1,
        parameters: [{ type: 'text', text: 'pedido-42' }]
      },
      {
        type: 'button', sub_type: 'copy_code', index: 3,
        parameters: [{ type: 'coupon_code', coupon_code: 'PIX123' }]
      }
    )
  end

  it 'keeps compatibility with button variables saved before indexed metadata' do
    result = build_params(
      'legacy_button' => {
        'type' => 'fixed', 'value' => 'pedido-42', 'component_type' => 'BUTTONS',
        'button_type' => 'url'
      }
    )

    expect(result.dig('processed_params', 'buttons')).to eq(
      [{ 'type' => 'url', 'parameter' => 'pedido-42' }]
    )
  end

  it 'keeps compatibility with variables saved before component-scoped keys' do
    result = build_params(
      'customer_name' => {
        'type' => 'customer_field', 'field' => 'name', 'component_type' => 'BODY'
      }
    )

    expect(result.dig('processed_params', 'body', 'customer_name')).to eq('Cliente Teste')
  end
end

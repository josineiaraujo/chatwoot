require 'rails_helper'

RSpec.describe Ibsoft::MetaTemplates::TemplatePayload do
  let(:base_attributes) do
    {
      name: 'lembrete_de_fatura',
      language: 'pt_BR',
      category: 'UTILITY',
      model: 'standard',
      parameter_format: 'named',
      header: {
        format: 'TEXT',
        text: 'Olá {{nome}}',
        examples: { nome: 'Maria' }
      },
      body: {
        text: 'A fatura {{referencia}} vence em {{vencimento}}.',
        examples: {
          referencia: '1234',
          vencimento: '10/08/2026'
        }
      },
      footer: { text: 'Equipe de atendimento' },
      buttons: [
        {
          type: 'URL',
          text: 'Abrir fatura',
          url: 'https://example.com/{{1}}',
          example: '1234'
        }
      ]
    }
  end

  it 'builds a named-variable standard template without leaking unknown fields' do
    payload = described_class.new(
      base_attributes.merge(ignored_secret: 'do-not-send')
    ).create_payload

    expect(payload).to include(
      'name' => 'lembrete_de_fatura',
      'language' => 'pt_BR',
      'category' => 'UTILITY',
      'parameter_format' => 'named'
    )
    expect(payload).not_to have_key('ignored_secret')
    expect(payload['components']).to include(
      include(
        'type' => 'HEADER',
        'example' => {
          'header_text_named_params' => [
            { 'param_name' => 'nome', 'example' => 'Maria' }
          ]
        }
      ),
      include(
        'type' => 'BODY',
        'example' => {
          'body_text_named_params' => [
            { 'param_name' => 'referencia', 'example' => '1234' },
            { 'param_name' => 'vencimento', 'example' => '10/08/2026' }
          ]
        }
      )
    )
  end

  it 'builds positional examples in Meta format' do
    attributes = base_attributes.deep_merge(
      parameter_format: 'positional',
      header: {
        text: 'Olá {{1}}',
        examples: { '1' => 'Maria' }
      },
      body: {
        text: 'A fatura {{1}} vence em {{2}}.',
        examples: { '1' => '1234', '2' => '10/08/2026' }
      }
    )

    payload = described_class.new(attributes).create_payload

    expect(payload['components']).to include(
      include('type' => 'HEADER', 'example' => { 'header_text' => ['Maria'] }),
      include(
        'type' => 'BODY',
        'example' => { 'body_text' => [%w[1234 10/08/2026]] }
      )
    )
  end

  it 'builds an authentication template using the Meta OTP contract' do
    payload = described_class.new(
      name: 'codigo_de_acesso',
      language: 'pt_BR',
      category: 'AUTHENTICATION',
      model: 'authentication',
      parameter_format: 'positional',
      authentication: {
        add_security_recommendation: true,
        code_expiration_minutes: 15,
        otp_type: 'COPY_CODE'
      }
    ).create_payload

    expect(payload['components']).to contain_exactly(
      {
        'type' => 'BODY',
        'add_security_recommendation' => true
      },
      {
        'type' => 'FOOTER',
        'code_expiration_minutes' => 15
      },
      {
        'type' => 'BUTTONS',
        'buttons' => [{ 'type' => 'OTP', 'otp_type' => 'COPY_CODE' }]
      }
    )
  end

  it 'builds a marketing catalog with the fixed Meta catalog action' do
    payload = described_class.new(
      base_attributes.deep_merge(
        category: 'MARKETING',
        model: 'catalog',
        header: { format: 'NONE', text: '', examples: {} },
        buttons: [],
        special: { button_text: 'Ver catálogo' }
      )
    ).create_payload

    expect(payload).to include(
      'category' => 'MARKETING',
      'parameter_format' => 'named'
    )
    expect(payload['components']).to contain_exactly(
      include('type' => 'BODY'),
      { 'type' => 'FOOTER', 'text' => 'Equipe de atendimento' },
      {
        'type' => 'BUTTONS',
        'buttons' => [{ 'type' => 'CATALOG', 'text' => 'Ver catálogo' }]
      }
    )
  end

  it 'builds order details for utility and marketing with the Meta display format' do
    %w[UTILITY MARKETING].each do |category|
      payload = described_class.new(
        base_attributes.deep_merge(
          category: category,
          model: 'order_details',
          header: {
            format: 'DOCUMENT',
            text: '',
            media_handle: 'meta-upload-handle',
            examples: {}
          },
          buttons: [],
          special: { button_text: 'Valor externo ignorado' }
        )
      ).create_payload

      expect(payload).to include(
        'category' => category,
        'display_format' => 'ORDER_DETAILS'
      )
      expect(payload['components']).to include(
        {
          'type' => 'HEADER',
          'format' => 'DOCUMENT',
          'example' => { 'header_handle' => ['meta-upload-handle'] }
        },
        {
          'type' => 'BUTTONS',
          'buttons' => [
            { 'type' => 'ORDER_DETAILS', 'text' => 'Copy Pix code' }
          ]
        }
      )
    end
  end

  it 'omits the header when order details uses no header' do
    attributes = base_attributes.deep_merge(
      model: 'order_details',
      header: { format: 'NONE', text: '', examples: {} },
      buttons: []
    )

    payload = described_class.new(attributes).create_payload

    expect(payload['components']).not_to include(include('type' => 'HEADER'))
    expect(payload['components']).to include(
      {
        'type' => 'BUTTONS',
        'buttons' => [
          { 'type' => 'ORDER_DETAILS', 'text' => 'Copy Pix code' }
        ]
      }
    )
  end

  it 'rejects a text header for order details' do
    attributes = base_attributes.deep_merge(
      model: 'order_details',
      header: {
        format: 'TEXT',
        text: 'Fatura {{cliente}}',
        examples: { cliente: 'Maria' }
      },
      buttons: []
    )

    operation = -> { described_class.new(attributes).create_payload }

    expect(&operation).to raise_error(described_class::ValidationError) do |error|
      expect(error.errors).to include(include(field: 'header'))
    end
  end

  it 'builds an order status using the Meta subcategory contract' do
    payload = described_class.new(
      base_attributes.deep_merge(
        model: 'order_status',
        header: { format: 'NONE', text: '', examples: {} },
        buttons: []
      )
    ).create_payload

    expect(payload).to include(
      'category' => 'UTILITY',
      'sub_category' => 'ORDER_STATUS'
    )
    expect(payload['components']).to contain_exactly(
      include('type' => 'BODY'),
      { 'type' => 'FOOTER', 'text' => 'Equipe de atendimento' }
    )
  end

  it 'builds call permission requests without generic interactive buttons' do
    payload = described_class.new(
      base_attributes.deep_merge(
        model: 'call_permission_request',
        buttons: []
      )
    ).create_payload

    expect(payload['components']).to contain_exactly(
      include('type' => 'HEADER'),
      include('type' => 'BODY'),
      { 'type' => 'FOOTER', 'text' => 'Equipe de atendimento' },
      { 'type' => 'CALL_PERMISSION_REQUEST' }
    )
  end

  it 'omits immutable identity fields when updating' do
    payload = described_class.new(base_attributes).update_payload

    expect(payload).not_to include('name', 'language')
    expect(payload).to include('category' => 'UTILITY')
  end

  it 'rejects missing examples and non-sequential positional variables' do
    attributes = base_attributes.deep_merge(
      parameter_format: 'positional',
      header: { format: 'NONE', text: '', examples: {} },
      body: {
        text: 'Faturas {{1}} e {{3}}',
        examples: { '1' => 'A' }
      }
    )

    operation = -> { described_class.new(attributes).create_payload }

    expect(&operation).to raise_error(Ibsoft::MetaTemplates::TemplatePayload::ValidationError) do |error|
      expect(error.errors.pluck(:field)).to include('body', 'body_examples')
    end
  end

  it 'requires uploaded media handles for media headers' do
    attributes = base_attributes.deep_merge(
      header: {
        format: 'IMAGE',
        text: '',
        media_handle: '',
        examples: {}
      }
    )

    operation = -> { described_class.new(attributes).create_payload }

    expect(&operation).to raise_error(Ibsoft::MetaTemplates::TemplatePayload::ValidationError) do |error|
      expect(error.errors).to include(
        include(field: 'media')
      )
    end
  end

  it 'rejects formats in unsupported categories and invalid special actions' do
    invalid_category = base_attributes.deep_merge(
      category: 'UTILITY',
      model: 'catalog',
      header: { format: 'NONE', text: '', examples: {} },
      buttons: [],
      special: { button_text: 'Ver catálogo' }
    )
    invalid_action = base_attributes.deep_merge(
      category: 'MARKETING',
      model: 'catalog',
      header: { format: 'NONE', text: '', examples: {} },
      buttons: [],
      special: { button_text: '' }
    )

    invalid_category_operation = lambda do
      described_class.new(invalid_category).create_payload
    end
    invalid_action_operation = lambda do
      described_class.new(invalid_action).create_payload
    end

    expect(&invalid_category_operation).to raise_error(described_class::ValidationError) do |error|
      expect(error.errors).to include(include(field: 'model'))
    end

    expect(&invalid_action_operation).to raise_error(described_class::ValidationError) do |error|
      expect(error.errors).to include(include(field: 'special_action'))
    end
  end

  it 'rejects generic buttons on formats with exclusive Meta actions' do
    attributes = base_attributes.deep_merge(
      model: 'call_permission_request'
    )

    operation = -> { described_class.new(attributes).create_payload }

    expect(&operation).to raise_error(described_class::ValidationError) do |error|
      expect(error.errors).to include(include(field: 'buttons'))
    end
  end
end

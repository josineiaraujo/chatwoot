require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrderUpdateTemplateSettings do
  let(:endpoint) { create(:ibsoft_external_message_endpoint) }
  let(:default_template) do
    {
      'id' => 'default-1',
      'name' => 'atualizacao_padrao',
      'language' => 'pt_BR',
      'parameter_format' => 'NAMED',
      'body_parameter' => { 'format' => 'named', 'key' => 'mensagem_status' }
    }
  end
  let(:override_template) do
    {
      'id' => 'paid-1',
      'name' => 'pagamento_confirmado',
      'language' => 'pt_BR',
      'parameter_format' => 'POSITIONAL',
      'body_parameter' => nil
    }
  end
  let(:catalog) { instance_double(Ibsoft::ExternalMessaging::OrderUpdateTemplateCatalog) }

  before do
    allow(catalog).to receive(:find).with('default-1').and_return(default_template)
    allow(catalog).to receive(:find).with('paid-1').and_return(override_template)
  end

  it 'stores a compact default descriptor and optional event overrides' do
    described_class.new(
      endpoint: endpoint,
      attributes: {
        mode: 'template',
        default_template_id: 'default-1',
        overrides: { payment_captured: 'paid-1' }
      },
      template_catalog: catalog
    ).assign

    expect(endpoint).to have_attributes(order_update_delivery_mode: 'template')
    expect(endpoint.order_update_template_settings).to eq(
      'default' => default_template,
      'overrides' => { 'payment_captured' => override_template }
    )
  end

  it 'removes template settings when interactive delivery is selected' do
    endpoint.order_update_delivery_mode = 'template'
    endpoint.order_update_template_settings = {
      'default' => default_template,
      'overrides' => {}
    }

    described_class.new(
      endpoint: endpoint,
      attributes: { mode: 'interactive' },
      template_catalog: catalog
    ).assign

    expect(endpoint).to have_attributes(
      order_update_delivery_mode: 'interactive',
      order_update_template_settings: {}
    )
  end

  it 'rejects a template mode without a compatible default template' do
    allow(catalog).to receive(:find).with('missing').and_return(nil)

    expect do
      described_class.new(
        endpoint: endpoint,
        attributes: { mode: 'template', default_template_id: 'missing' },
        template_catalog: catalog
      ).assign
    end.to raise_error(described_class::ValidationError) { |error|
      expect(error.code).to eq('order_update_template_invalid')
    }
  end

  it 'rejects event keys outside the supported message catalog' do
    expect do
      described_class.new(
        endpoint: endpoint,
        attributes: {
          mode: 'template',
          default_template_id: 'default-1',
          overrides: { unknown_event: 'paid-1' }
        },
        template_catalog: catalog
      ).assign
    end.to raise_error(described_class::ValidationError) { |error|
      expect(error.code).to eq('order_update_template_override_invalid')
    }
  end
end

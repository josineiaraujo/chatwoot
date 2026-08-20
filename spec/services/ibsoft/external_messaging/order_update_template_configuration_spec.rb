require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrderUpdateTemplateConfiguration do
  let(:descriptor) do
    {
      'id' => 'template-1',
      'name' => 'atualizacao_fatura',
      'language' => 'pt_BR',
      'parameter_format' => 'NAMED',
      'body_parameter' => { 'format' => 'named', 'key' => 'mensagem_status' }
    }
  end

  it 'accepts a compatible default template and supported event overrides' do
    configuration = described_class.new(
      mode: 'template',
      settings: {
        default: descriptor,
        overrides: { payment_captured: descriptor.merge('id' => 'template-2') }
      }
    )

    expect(configuration).to be_valid
    expect(configuration).to be_ready
  end

  it 'accepts a template without a body variable' do
    configuration = described_class.new(
      mode: 'template',
      settings: {
        default: descriptor.merge('parameter_format' => 'POSITIONAL', 'body_parameter' => nil),
        overrides: {}
      }
    )

    expect(configuration).to be_valid
  end

  it 'clears template settings in interactive mode' do
    configuration = described_class.new(
      mode: 'interactive',
      settings: { default: descriptor, overrides: {} }
    )

    expect(configuration.normalized_settings).to eq({})
    expect(configuration).to be_valid
    expect(configuration).not_to be_ready
  end

  it 'rejects unknown events and mismatched parameter formats', :aggregate_failures do
    unknown_event = described_class.new(
      mode: 'template',
      settings: { default: descriptor, overrides: { unknown_event: descriptor } }
    )
    invalid_parameter = described_class.new(
      mode: 'template',
      settings: {
        default: descriptor.merge('body_parameter' => { 'format' => 'positional', 'key' => '1' }),
        overrides: {}
      }
    )

    expect(unknown_event).not_to be_valid
    expect(invalid_parameter).not_to be_valid
  end
end

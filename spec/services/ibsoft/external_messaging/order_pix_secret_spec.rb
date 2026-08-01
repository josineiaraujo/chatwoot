require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrderPixSecret do
  let(:components) do
    [
      {
        'type' => 'button',
        'parameters' => [
          {
            'action' => {
              'order_details' => {
                'payment_settings' => [
                  {
                    'type' => 'pix_dynamic_code',
                    'pix_dynamic_code' => {
                      'code' => 'PIX-CODE',
                      'merchant_name' => 'IBSoft Cloud',
                      'key' => '12345678000199',
                      'key_type' => 'CNPJ'
                    }
                  }
                ]
              }
            }
          }
        ]
      }
    ]
  end

  it 'extracts the PIX key from persisted components and restores it only in memory', :aggregate_failures do
    extracted = described_class.extract(components)

    expect(extracted.key).to eq('12345678000199')
    expect(extracted.components.to_json).not_to include('12345678000199')

    materialized = described_class.materialize(
      components: extracted.components,
      key: extracted.key
    )
    expect(materialized.to_json).to include('12345678000199')
    expect(extracted.components.to_json).not_to include('12345678000199')
  end

  it 'rejects a referenced PIX key that is no longer available' do
    extracted = described_class.extract(components)

    expect do
      described_class.materialize(components: extracted.components, key: nil)
    end.to raise_error(described_class::MissingKey)
  end
end

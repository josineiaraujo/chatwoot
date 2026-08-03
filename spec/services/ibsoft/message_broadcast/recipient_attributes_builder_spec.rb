require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::RecipientAttributesBuilder do
  it 'keeps normalized primary and fallback numbers in priority order', :aggregate_failures do
    result = described_class.new(
      attributes: {
        external_customer_id: '4797',
        customer_name: 'Cliente IXC',
        primary_phone: '(75) 98247-9788',
        fallback_phone: '(75) 99999-9999',
        template_variable_values: { customer_name: " Cliente\nIXC " }
      }
    ).call

    expect(result).to include(
      primary_phone: '+5575982479788',
      fallback_phone: '+5575999999999',
      phone_status: 'primary',
      status: 'pending',
      error_code: nil
    )
    expect(result[:template_variable_values]).to eq('customer_name' => 'Cliente IXC')
  end

  it 'promotes a valid fallback without changing its origin label', :aggregate_failures do
    result = described_class.new(
      attributes: {
        external_customer_id: '4797',
        name: 'Cliente IXC',
        primary_phone: 'invalid',
        fallback_phone: '(75) 99999-9999'
      }
    ).call

    expect(result).to include(
      primary_phone: nil,
      fallback_phone: '+5575999999999',
      phone_status: 'fallback',
      status: 'pending'
    )
  end

  it 'marks a recipient without a valid phone as skipped' do
    result = described_class.new(
      attributes: { external_customer_id: '4797', name: 'Cliente IXC' }
    ).call

    expect(result).to include(
      primary_phone: nil,
      fallback_phone: nil,
      phone_status: 'unavailable',
      status: 'skipped',
      error_code: 'without_valid_phone'
    )
  end

  it 'ignores an entry without an external customer id' do
    expect(described_class.new(attributes: { name: 'Cliente IXC' }).call).to be_nil
  end
end

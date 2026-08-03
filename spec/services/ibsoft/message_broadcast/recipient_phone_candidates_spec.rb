require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::RecipientPhoneCandidates do
  it 'keeps the primary phone before the fallback phone' do
    candidates = described_class.new(
      primary_phone: '(75) 98247-9788',
      fallback_phone: '(75) 99999-9999'
    ).call

    expect(candidates.map(&:to_h)).to eq(
      [
        { kind: 'primary', phone_number: '+5575982479788', source_id: '5575982479788' },
        { kind: 'fallback', phone_number: '+5575999999999', source_id: '5575999999999' }
      ]
    )
  end

  it 'promotes the fallback when the primary phone is invalid' do
    candidates = described_class.new(
      primary_phone: 'invalid',
      fallback_phone: '75999999999'
    ).call

    expect(candidates.map(&:to_h)).to eq(
      [{ kind: 'fallback', phone_number: '+5575999999999', source_id: '5575999999999' }]
    )
  end

  it 'does not attempt the same number twice' do
    candidates = described_class.new(
      primary_phone: '+55 (75) 98247-9788',
      fallback_phone: '75982479788'
    ).call

    expect(candidates.map(&:kind)).to eq(['primary'])
  end
end

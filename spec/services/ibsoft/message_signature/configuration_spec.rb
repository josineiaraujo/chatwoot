# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ibsoft::MessageSignature::Configuration do
  let(:account) { create(:account) }

  it 'is disabled by default without selected communication channels' do
    configuration = described_class.new(account)

    expect(configuration.payload).to eq(enabled: false, inbox_ids: [])
    expect(configuration.enabled_for_inbox?(1)).to be(false)
  end

  it 'normalizes persisted channel identifiers' do
    account.update!(
      settings: {
        described_class::SETTINGS_KEY => {
          enabled: 'true',
          inbox_ids: ['3', 1, 'invalid', 3, -1]
        }
      }
    )

    configuration = described_class.new(account)

    expect(configuration.payload).to eq(enabled: true, inbox_ids: [1, 3])
    expect(configuration.enabled_for_inbox?(3)).to be(true)
    expect(configuration.enabled_for_inbox?(2)).to be(false)
  end
end

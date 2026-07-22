# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ibsoft::MessageSignature::ConfigurationUpdater do
  let(:account) { create(:account, settings: { 'unrelated_setting' => { 'enabled' => true } }) }
  let!(:first_inbox) { create(:inbox, account: account) }
  let!(:second_inbox) { create(:inbox, account: account) }

  it 'persists a normalized account-scoped configuration without replacing unrelated settings' do
    payload = described_class.new(
      account: account,
      params: { enabled: true, inbox_ids: [second_inbox.id.to_s, first_inbox.id, second_inbox.id] }
    ).call

    expect(payload).to eq(enabled: true, inbox_ids: [first_inbox.id, second_inbox.id].sort)
    expect(account.reload.settings['unrelated_setting']).to eq('enabled' => true)
  end

  it 'rejects channels from another account' do
    foreign_inbox = create(:inbox)

    expect do
      described_class.new(
        account: account,
        params: { enabled: true, inbox_ids: [first_inbox.id, foreign_inbox.id] }
      ).call
    end.to raise_error(described_class::ValidationError) { |error| expect(error.code).to eq(:inbox_ids_not_found) }
  end

  it 'requires a channel when the feature is enabled' do
    expect do
      described_class.new(account: account, params: { enabled: true, inbox_ids: [] }).call
    end.to raise_error(described_class::ValidationError) { |error| expect(error.code).to eq(:inbox_ids_required) }
  end

  it 'rejects malformed channel identifiers' do
    expect do
      described_class.new(account: account, params: { enabled: false, inbox_ids: ['invalid'] }).call
    end.to raise_error(described_class::ValidationError) { |error| expect(error.code).to eq(:inbox_ids_invalid) }
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob do
  let(:account) { create(:account) }
  let(:connection) { create(:ibsoft_erp_connection, account: account, provider: 'ixc') }
  let(:search) { instance_double(Ibsoft::MessageBroadcast::RecipientSearch) }
  let(:payload) do
    {
      account_id: account.id,
      connection_id: connection.id,
      mode: 'direct',
      filters: { 'active' => true },
      token: 'search-token',
      lock_token: 'lock-token'
    }
  end

  it { expect(described_class.queue_name).to eq('medium') }

  it 'delegates cache construction using account-scoped records' do
    allow(Ibsoft::MessageBroadcast::RecipientSearch).to receive(:new).and_return(search)
    allow(search).to receive(:build_cache)

    described_class.perform_now(payload)

    expect(Ibsoft::MessageBroadcast::RecipientSearch).to have_received(:new).with(
      account: account,
      connection: connection
    )
    expect(search).to have_received(:build_cache).with(
      mode: 'direct',
      filters: { 'active' => true },
      token: 'search-token',
      lock_token: 'lock-token'
    )
  end

  it 'does nothing when the connection does not belong to the account' do
    other_account = create(:account)
    payload[:connection_id] = create(:ibsoft_erp_connection, account: other_account).id
    allow(Ibsoft::MessageBroadcast::RecipientSearch).to receive(:new)

    described_class.perform_now(payload)

    expect(Ibsoft::MessageBroadcast::RecipientSearch).not_to have_received(:new)
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::CachedRecipientSelection do
  let(:account) { create(:account) }
  let(:connection) { create(:ibsoft_erp_connection, account: account, provider: 'ixc') }
  let(:cache) { Ibsoft::MessageBroadcast::RecipientSearchCache.new(account: account, connection: connection) }
  let(:token) { cache.token_for('direct', active: true) }

  after do
    Redis::Alfred.scan_each(
      match: "ibsoft:message_broadcast:recipient_search:#{account.id}:*"
    ) { |key| Redis::Alfred.delete(key) }
  end

  it 'reads a complete account-scoped snapshot' do
    customers = Array.new(600) do |index|
      {
        external_id: (index + 1).to_s,
        name: "Cliente #{index + 1}",
        city_name: index == 525 ? 'Seabra' : 'Salvador'
      }
    end
    cache.write(token, customers: customers)

    selection = described_class.new(account: account, connection: connection)
    result = selection.call(token: token)
    filtered_result = selection.call(token: token, query: 'seabra')

    expect(result.size).to eq(600)
    expect(filtered_result.sole).to include('external_id' => '526', 'name' => 'Cliente 526')
  end

  it 'rejects missing or expired snapshots' do
    selection = described_class.new(account: account, connection: connection)

    expect { selection.call(token: 'expired') }
      .to raise_error(described_class::SnapshotUnavailableError)
  end
end

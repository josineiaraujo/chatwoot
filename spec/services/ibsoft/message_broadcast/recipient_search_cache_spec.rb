require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::RecipientSearchCache do
  let(:account) { create(:account) }
  let(:connection) { create(:ibsoft_erp_connection, account: account, provider: 'ixc') }
  let(:cache) { described_class.new(account: account, connection: connection) }
  let(:token) { cache.token_for('direct', active: true) }

  after do
    Redis::Alfred.scan_each(
      match: "ibsoft:message_broadcast:recipient_search:#{account.id}:*"
    ) { |key| Redis::Alfred.delete(key) }
  end

  it 'writes compressed chunks and reads only the requested page' do
    cache.write(token, customers: customers(600), source_total: 600, source_returned: 600)

    metadata = cache.metadata(token)
    result = cache.page(token: token, page: 26, per_page: 10)

    expect(metadata).to include('status' => 'ready', 'chunk_count' => 3, 'total' => 600)
    expect(result[:customers].first['external_id']).to eq('251')
    expect(result[:customers].last['external_id']).to eq('260')
    expect(Redis::Alfred.ttl(cache_key(':meta'))).to be_between(1, described_class::TTL)
  end

  it 'filters all chunks using accent-insensitive normalized values' do
    records = customers(300)
    records[275]['name'] = 'João da Conceição'
    cache.write(token, customers: records, source_total: 300, source_returned: 300)

    result = cache.page(token: token, page: 1, per_page: 10, query: 'joao da conceicao')

    expect(result[:total]).to eq(1)
    expect(result[:customers].sole['external_id']).to eq('276')
  end

  it 'uses an ownership token to release the distributed build lock' do
    owner_token = cache.acquire_build_lock(token)

    expect(owner_token).to be_present
    expect(cache.acquire_build_lock(token)).to be_nil

    cache.release_build_lock(token, 'another-owner')
    expect(cache.acquire_build_lock(token)).to be_nil

    cache.release_build_lock(token, owner_token)
    expect(cache.acquire_build_lock(token)).to be_present
  end

  private

  def customers(count)
    Array.new(count) do |index|
      {
        external_id: (index + 1).to_s,
        name: "Cliente #{index + 1}",
        document: "000#{index + 1}",
        address: "Rua #{index + 1}",
        neighborhood: 'Centro',
        city_name: 'Salvador',
        state: 'BA',
        zip_code: '40000-000',
        phone_selection: {
          primary_phone: '+5571999999999',
          fallback_phone: nil,
          deliverable: true,
          reason: 'primary_only'
        }
      }
    end
  end

  def cache_key(suffix)
    "ibsoft:message_broadcast:recipient_search:#{account.id}:#{connection.id}:#{token}#{suffix}"
  end
end

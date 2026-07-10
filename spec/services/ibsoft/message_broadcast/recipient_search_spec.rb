require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::RecipientSearch do
  let(:account) { create(:account) }
  let(:connection) { create(:ibsoft_erp_connection, account: account, provider: 'ixc') }
  let(:adapter) { instance_double(Ibsoft::Erp::Adapters::Ixc::CustomerSearch) }
  let(:customers) do
    Array.new(30) do |index|
      Ibsoft::Erp::NormalizedCustomer.new(
        external_id: index + 1,
        name: "Cliente #{index + 1}",
        document: "000#{index + 1}",
        address: "Rua #{index + 1}",
        neighborhood: 'Centro',
        city_name: 'Salvador',
        state: 'BA',
        phone_candidates: [{ source: 'whatsapp', value: '71999999999' }]
      )
    end
  end
  let(:search_result) do
    Ibsoft::Erp::CustomerSearchResult.new(
      customers: customers,
      source_total: customers.size,
      source_returned: customers.size,
      has_more: false
    )
  end

  before do
    allow(Ibsoft::Erp::Adapters::Ixc::CustomerSearch).to receive(:new).and_return(adapter)
    allow(adapter).to receive(:call_all).and_return(search_result)
  end

  after do
    Redis::Alfred.scan_each(
      match: "ibsoft:message_broadcast:recipient_search:#{account.id}:*"
    ) { |key| Redis::Alfred.delete(key) }
  end

  it 'enqueues one cache build and reuses the ready snapshot across pages' do
    enqueued_payload = nil
    allow(Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob).to receive(:perform_later) do |payload|
      enqueued_payload = payload
    end

    first_call = search.call(
      mode: 'direct',
      filters: { active: true, city_ids: %w[2 1] },
      pagination: { page: 1, per_page: 10 }
    )
    duplicate_call = search.call(
      mode: 'direct',
      filters: { city_ids: %w[1 2], active: true },
      pagination: { page: 1, per_page: 10 }
    )

    expect(first_call[:status]).to eq('building')
    expect(duplicate_call[:status]).to eq('building')
    expect(Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob).to have_received(:perform_later).once

    Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob.perform_now(enqueued_payload)
    second_page = search.call(
      mode: 'direct',
      filters: { active: true, city_ids: %w[1 2] },
      pagination: { page: 2, per_page: 10 }
    )

    expect(second_page).to include(status: 'ready', total: 30, total_pages: 3, cache_hit: true)
    expect(second_page[:customers].first['external_id']).to eq('11')
    expect(adapter).to have_received(:call_all).once
  end

  it 'searches the complete cached snapshot without rebuilding it' do
    payload = capture_build_payload
    Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob.perform_now(payload)

    result = search.call(
      mode: 'direct',
      filters: {},
      pagination: { page: 1, per_page: 10 },
      query: 'cliente 30'
    )

    expect(result).to include(status: 'ready', total: 1, total_pages: 1)
    expect(result[:customers].sole['external_id']).to eq('30')
    expect(adapter).to have_received(:call_all).once
  end

  it 'stores only fields required by recipient selection and template variables' do
    payload = capture_build_payload
    Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob.perform_now(payload)

    result = search.call(mode: 'direct', filters: {}, pagination: { page: 1, per_page: 1 })
    customer = result[:customers].sole

    expect(customer.keys).to contain_exactly(
      'active', 'address', 'city_name', 'document', 'external_id', 'name',
      'neighborhood', 'phone_selection', 'state', 'zip_code'
    )
    expect(customer['phone_selection'].keys).to contain_exactly(
      'deliverable', 'fallback_phone', 'primary_phone', 'reason'
    )
  end

  it 'invalidates a ready snapshot only when an explicit refresh is requested' do
    payload = capture_build_payload
    Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob.perform_now(payload)

    result = search.call(mode: 'direct', filters: {}, refresh: true)

    expect(result[:status]).to eq('building')
    expect(Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob).to have_received(:perform_later).twice
  end

  it 'keeps a failed build stopped until an explicit refresh' do
    allow(adapter).to receive(:call_all).and_raise(Ibsoft::Erp::Adapters::Ixc::Client::RequestError, 'IXC unavailable')
    payload = capture_build_payload

    expect do
      Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob.perform_now(payload)
    end.not_to raise_error

    failed_result = search.call(mode: 'direct', filters: {})

    expect(failed_result[:status]).to eq('failed')
    expect(Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob).to have_received(:perform_later).once
  end

  it 'does not let a stale job overwrite a snapshot after losing its lock' do
    payload = capture_build_payload
    cache = Ibsoft::MessageBroadcast::RecipientSearchCache.new(account: account, connection: connection)
    allow(adapter).to receive(:call_all) do
      cache.release_build_lock(payload[:token], payload[:lock_token])
      cache.acquire_build_lock(payload[:token])
      search_result
    end

    Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob.perform_now(payload)

    expect(cache.metadata(payload[:token])).to include('status' => 'building')
  end

  it 'keeps cache keys isolated by ERP connection' do
    other_connection = create(:ibsoft_erp_connection, account: account, provider: 'ixc')
    allow(Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob).to receive(:perform_later)

    search.call(mode: 'direct', filters: {})
    described_class.new(account: account, connection: other_connection).call(mode: 'direct', filters: {})

    expect(Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob).to have_received(:perform_later).twice
  end

  private

  def search
    @search ||= described_class.new(account: account, connection: connection)
  end

  def capture_build_payload
    payload = nil
    allow(Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob).to receive(:perform_later) do |job_payload|
      payload = job_payload
    end
    search.call(mode: 'direct', filters: {})
    payload
  end
end

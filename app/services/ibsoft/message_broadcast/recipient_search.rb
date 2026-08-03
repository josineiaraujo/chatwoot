class Ibsoft::MessageBroadcast::RecipientSearch
  DEFAULT_PER_PAGE = 10
  MAX_PER_PAGE = 500

  def self.supports?(provider)
    Ibsoft::Erp::Adapters::Registry.supports_search?(provider)
  end

  def initialize(account:, connection:)
    @account = account
    @connection = connection
    @cache = Ibsoft::MessageBroadcast::RecipientSearchCache.new(account: account, connection: connection)
  end

  def call(mode:, filters:, pagination: {}, query: nil, refresh: false)
    page = normalized_page(pagination[:page])
    per_page = normalized_per_page(pagination[:per_page])
    token = cache.token_for(mode, filters)
    metadata = cache.metadata(token)
    if refresh && metadata.present?
      cache.invalidate(token)
      metadata = nil
    end

    return ready_result(token, metadata, page, per_page, query) if metadata&.fetch('status', nil) == 'ready'
    return pending_result(token, metadata) if metadata&.fetch('status', nil) == 'failed'

    enqueue_build(token, mode, filters)
    pending_result(token, metadata)
  rescue Ibsoft::MessageBroadcast::RecipientSearchCache::CorruptedSnapshotError
    cache.invalidate(token)
    enqueue_build(token, mode, filters)
    pending_result(token, nil)
  end

  def build_cache(mode:, filters:, token:, lock_token:)
    return unless cache.lock_owned?(token, lock_token)

    result = search_adapter.call_all(mode: mode, filters: filters)
    return unless cache.lock_owned?(token, lock_token)

    cache.write(
      token,
      customers: result.customers.map { |customer| customer_payload(customer) },
      source_total: result.source_total,
      source_returned: result.source_returned
    )
  rescue StandardError => e
    cache.mark_failed(token, error_code: e.class.name) if cache.lock_owned?(token, lock_token)
    Rails.logger.error("[Ibsoft::MessageBroadcast] recipient cache build failed: #{e.class}")
  ensure
    cache.release_build_lock(token, lock_token)
  end

  private

  attr_reader :account, :connection, :cache

  def ready_result(token, metadata, page, per_page, query)
    cached_page = cache.page(token: token, page: page, per_page: per_page, query: query)
    total = cached_page.fetch(:total)

    {
      status: 'ready',
      customers: cached_page.fetch(:customers),
      total: total,
      source_total: metadata.fetch('source_total').to_i,
      source_returned: metadata.fetch('source_returned').to_i,
      has_more: page * per_page < total,
      page: page,
      per_page: per_page,
      total_pages: (total.to_f / per_page).ceil,
      search_token: token,
      cache_hit: true,
      cache_expires_in: Ibsoft::MessageBroadcast::RecipientSearchCache::TTL
    }
  end

  def pending_result(token, metadata)
    {
      status: metadata&.fetch('status', nil) == 'failed' ? 'failed' : 'building',
      customers: [],
      total: 0,
      search_token: token,
      cache_hit: false,
      retry_after: 1,
      error_code: metadata&.fetch('error_code', nil)
    }.compact
  end

  def enqueue_build(token, mode, filters)
    lock_token = cache.acquire_build_lock(token)
    return unless lock_token

    cache.mark_building(token)
    Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob.perform_later(
      account_id: account.id,
      connection_id: connection.id,
      mode: mode.to_s,
      filters: filters.to_h.deep_stringify_keys,
      token: token,
      lock_token: lock_token
    )
  rescue StandardError
    cache.release_build_lock(token, lock_token) if lock_token
    cache.invalidate(token)
    raise
  end

  def search_adapter
    Ibsoft::Erp::Adapters::Registry.search(connection)
  end

  def customer_payload(customer)
    selection = phone_selector.call(customer).payload

    {
      external_id: customer.external_id,
      name: customer.name,
      document: customer.document,
      active: customer.active,
      zip_code: customer.zip_code,
      address: customer.address,
      neighborhood: customer.neighborhood,
      city_name: customer.city_name,
      state: customer.state,
      phone_selection: selection.slice(:primary_phone, :fallback_phone, :deliverable, :reason)
    }
  end

  def phone_selector
    @phone_selector ||= Ibsoft::MessageBroadcast::PhoneSelector.new
  end

  def normalized_page(value)
    value.to_i.positive? ? value.to_i : 1
  end

  def normalized_per_page(value)
    requested_value = value.to_i
    requested_value = DEFAULT_PER_PAGE unless requested_value.positive?
    [requested_value, MAX_PER_PAGE].min
  end
end

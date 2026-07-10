class Ibsoft::Erp::Adapters::Ixc::Search::BaseSearch
  DEFAULT_LIMIT = 100
  MAX_LIMIT = 500
  SOURCE_PAGE_SIZE = 500
  MAX_SOURCE_RECORDS = 10_000

  def initialize(client, lookups: nil)
    @client = client
    @lookups = lookups || Ibsoft::Erp::Adapters::Ixc::Lookups.new(client)
  end

  private

  attr_reader :client, :lookups

  def normalized_limit(limit)
    value = limit.to_i
    value = DEFAULT_LIMIT if value <= 0
    [value, MAX_LIMIT].min
  end

  def normalized_page(page)
    value = page.to_i
    value <= 0 ? 1 : value
  end

  def page_offset(page, per_page)
    (normalized_page(page) - 1) * normalized_limit(per_page)
  end

  def active_value(value)
    ActiveModel::Type::Boolean.new.cast(value) ? 'S' : 'N'
  end

  def array_query(value)
    Array(value).compact_blank.map(&:to_s).uniq.join(',')
  end

  def client_batch_fetcher
    @client_batch_fetcher ||= Ibsoft::Erp::Adapters::Ixc::ClientBatchFetcher.new(client, lookups: lookups)
  end

  def complete_result(customers, source_total:, source_returned:)
    Ibsoft::Erp::CustomerSearchResult.new(
      customers: customers,
      source_total: source_total,
      source_returned: source_returned,
      has_more: false,
      pagination: { page: 1, per_page: customers.size }
    )
  end
end

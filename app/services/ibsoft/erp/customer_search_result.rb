class Ibsoft::Erp::CustomerSearchResult
  attr_reader :customers, :source_total, :source_returned, :has_more, :page, :per_page

  def initialize(customers:, source_total:, source_returned:, has_more:, pagination: {})
    @customers = customers
    @source_total = source_total.to_i
    @source_returned = source_returned.to_i
    @has_more = has_more
    @page = normalized_page(pagination[:page])
    @per_page = normalized_per_page(pagination[:per_page])
  end

  def payload
    {
      customers: customers.map(&:payload),
      source_total: source_total,
      source_returned: source_returned,
      has_more: has_more,
      page: page,
      per_page: per_page
    }
  end

  private

  def normalized_page(value)
    value.to_i <= 0 ? 1 : value.to_i
  end

  def normalized_per_page(value)
    value.to_i <= 0 ? customers.size : value.to_i
  end
end

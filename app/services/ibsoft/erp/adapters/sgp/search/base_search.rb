class Ibsoft::Erp::Adapters::Sgp::Search::BaseSearch
  DEFAULT_LIMIT = 100
  MAX_LIMIT = 500

  def initialize(client, lookups: nil)
    @client = client
    @lookups = lookups || Ibsoft::Erp::Adapters::Sgp::Lookups.new(client)
  end

  private

  attr_reader :client, :lookups

  def customer_catalog
    @customer_catalog ||= Ibsoft::Erp::Adapters::Sgp::CustomerCatalog.new(client)
  end

  def mapper
    @mapper ||= Ibsoft::Erp::Adapters::Sgp::CustomerMapper.new
  end

  def paged_result(result, limit, page)
    limit = normalized_limit(limit)
    page = normalized_page(page)
    offset = (page - 1) * limit

    Ibsoft::Erp::CustomerSearchResult.new(
      customers: result.customers.slice(offset, limit) || [],
      source_total: result.source_total,
      source_returned: result.source_returned,
      has_more: offset + limit < result.customers.size,
      pagination: { page: page, per_page: limit }
    )
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

  def filter_customers(customers, filters)
    active_filter = if filters.key?(:client_active)
                      filters[:client_active]
                    else
                      filters[:active]
                    end

    customers.select do |customer|
      active_matches?(customer, active_filter) &&
        exact_matches?(customer.state_id, filters[:state_id]) &&
        city_matches?(customer, filters)
    end
  end

  def city_matches?(customer, filters)
    return exact_matches?(customer.city_name, filters[:city_name]) if filters[:city_name].present?

    exact_matches?(customer.city_id, filters[:city_id])
  end

  def active_matches?(customer, value)
    return true unless boolean_filter_present?(value)

    customer.active == ActiveModel::Type::Boolean.new.cast(value)
  end

  def exact_matches?(candidate, expected)
    expected.blank? || normalized_text(candidate) == normalized_text(expected)
  end

  def contains?(candidate, expected)
    expected.blank? || normalized_text(candidate).include?(normalized_text(expected))
  end

  def normalized_text(value)
    I18n.transliterate(value.to_s).downcase.strip
  end

  def list_values(value)
    Array(value).flat_map { |item| item.to_s.split(',') }
                .map(&:strip)
                .compact_blank
                .uniq
  end

  def boolean_filter_present?(value)
    value == false || value.present?
  end

  def normalized_limit(value)
    requested = value.to_i
    requested = DEFAULT_LIMIT unless requested.positive?
    [requested, MAX_LIMIT].min
  end

  def normalized_page(value)
    requested = value.to_i
    requested.positive? ? requested : 1
  end
end

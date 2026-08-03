class Ibsoft::Erp::Adapters::Sgp::Search::DirectClientSearch < Ibsoft::Erp::Adapters::Sgp::Search::BaseSearch
  def call(filters:, limit: DEFAULT_LIMIT, page: 1)
    paged_result(call_all(filters: filters), limit, page)
  end

  def call_all(filters:)
    filters = filters.to_h.with_indifferent_access
    source = customer_catalog.call(
      filters: { cliente_nome: filters[:name] }.compact_blank,
      include_contracts: true
    )
    customers = mapper.map_records(source.records, source: 'direct')
    customers = filter_customers(customers, filters)
    customers = apply_text_filters(customers, filters)

    complete_result(
      customers,
      source_total: source.source_total,
      source_returned: source.source_returned
    )
  end

  private

  def apply_text_filters(customers, filters)
    customers.select do |customer|
      contains?(customer.name, filters[:name]) &&
        contains?(customer.address, filters[:street]) &&
        contains?(customer.neighborhood, filters[:neighborhood]) &&
        exact_matches?(customer.zip_code.to_s.gsub(/\D/, ''), normalized_zip(filters[:zip_code]))
    end
  end

  def normalized_zip(value)
    return if value.blank?

    value.to_s.gsub(/\D/, '')
  end
end

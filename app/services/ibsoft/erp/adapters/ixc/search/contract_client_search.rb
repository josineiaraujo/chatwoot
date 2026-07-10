class Ibsoft::Erp::Adapters::Ixc::Search::ContractClientSearch < Ibsoft::Erp::Adapters::Ixc::Search::BaseSearch
  def call(filters:, limit: DEFAULT_LIMIT, page: 1)
    limit = normalized_limit(limit)
    page = normalized_page(page)
    filters = filters.to_h.with_indifferent_access
    return filtered_customer_result(filters, limit, page) if customer_filters?(filters)

    records, total = contract_records(filters, needed_unique_ids: page * limit)
    client_ids = records.pluck('id_cliente').compact_blank.uniq
    page_client_ids = client_ids.slice(page_offset(page, limit), limit) || []
    customers = client_batch_fetcher.call(
      client_ids: page_client_ids,
      active: filters[:client_active],
      source: 'contracts'
    )

    Ibsoft::Erp::CustomerSearchResult.new(
      customers: customers,
      source_total: total,
      source_returned: records.size,
      has_more: total > records.size || client_ids.size > page * limit,
      pagination: { page: page, per_page: limit }
    )
  end

  def call_all(filters:)
    filters = filters.to_h.with_indifferent_access
    records, total = contract_records(filters, needed_unique_ids: MAX_SOURCE_RECORDS)
    client_ids = records.pluck('id_cliente').compact_blank.uniq
    customers = client_batch_fetcher.call(
      client_ids: client_ids,
      active: filters[:client_active],
      location: customer_location_filters(filters),
      source: 'contracts'
    )

    complete_result(customers, source_total: total, source_returned: records.size)
  end

  private

  def filtered_customer_result(filters, limit, page)
    source = filtered_customers(filters, target_count: (page * limit) + 1)
    paged_customers = source[:customers].slice(page_offset(page, limit), limit) || []

    Ibsoft::Erp::CustomerSearchResult.new(
      customers: paged_customers,
      source_total: source[:total],
      source_returned: source[:records_count],
      has_more: source[:customers].size > page * limit || !source[:exhausted],
      pagination: { page: page, per_page: limit }
    )
  end

  def filtered_customers(filters, target_count:)
    source = filtered_source_state

    loop do
      response = client.list('cliente_contrato', contract_payload(filters, source[:page]))
      source[:total] = response.total
      source[:records_count] += response.records.size
      append_filtered_clients(source, response.records, filters)
      break if filtered_source_complete?(source, response, target_count)

      source[:page] += 1
    end

    filtered_source_result(source)
  end

  def filtered_source_state
    {
      customers: [],
      records_count: 0,
      total: 0,
      page: 1,
      seen_client_ids: {}
    }
  end

  def append_filtered_clients(source, records, filters)
    client_ids = unseen_client_ids(records, source[:seen_client_ids])
    return if client_ids.empty?

    source[:customers].concat(filtered_client_batch(client_ids, filters))
  end

  def filtered_source_complete?(source, response, target_count)
    source[:customers].size >= target_count ||
      source[:records_count] >= source[:total] ||
      source[:records_count] >= MAX_SOURCE_RECORDS ||
      response.records.empty?
  end

  def filtered_source_result(source)
    {
      customers: source[:customers],
      records_count: source[:records_count],
      total: source[:total],
      exhausted: source[:records_count] >= source[:total]
    }
  end

  def unseen_client_ids(records, seen_client_ids)
    records.pluck('id_cliente').compact_blank.map(&:to_s).uniq.reject do |client_id|
      seen_client_ids.key?(client_id).tap { |seen| seen_client_ids[client_id] = true unless seen }
    end
  end

  def filtered_client_batch(client_ids, filters)
    client_batch_fetcher.call(
      client_ids: client_ids,
      active: filters[:client_active],
      location: customer_location_filters(filters),
      source: 'contracts'
    )
  end

  def contract_records(filters, needed_unique_ids:)
    records = []
    total = 0
    page = 1

    loop do
      response = client.list('cliente_contrato', contract_payload(filters, page))
      total = response.total
      records.concat(response.records)
      break if records.pluck('id_cliente').compact_blank.uniq.size >= needed_unique_ids
      break if records.size >= total
      break if records.size >= MAX_SOURCE_RECORDS
      break if response.records.empty?

      page += 1
    end

    [records, total]
  end

  def customer_filters?(filters)
    filter_present?(filters[:client_active]) ||
      customer_location_filters(filters).values.any? { |value| filter_present?(value) }
  end

  def customer_location_filters(filters)
    {
      city_id: filters[:city_id],
      state_id: filters[:state_id]
    }
  end

  def filter_present?(value)
    value == false || value.present?
  end

  def contract_payload(filters, page)
    primary_filter, additional_filters = split_contract_filters(filters)

    Ibsoft::Erp::Adapters::Ixc::QueryBuilder.payload(
      table: 'cliente_contrato',
      field: primary_filter[:field],
      query: primary_filter[:value],
      operator: primary_filter[:operator],
      page: page,
      per_page: SOURCE_PAGE_SIZE,
      sort_field: 'cliente_contrato.id',
      sort_order: 'desc',
      filters: additional_filters
    )
  end

  def split_contract_filters(filters)
    raw_filters = []
    raw_filters << in_filter('cliente_contrato.status', filters[:contract_statuses])
    raw_filters << in_filter('cliente_contrato.status_internet', filters[:internet_statuses])
    raw_filters << in_filter('cliente_contrato.id_vd_contrato', filters[:plan_ids])
    raw_filters << exact_filter('cliente_contrato.bloqueio_automatico', active_value(filters[:automatic_block])) unless filters[:automatic_block].nil?
    raw_filters.compact!

    primary_filter = raw_filters.shift || {
      field: 'cliente_contrato.id',
      value: '1',
      operator: '>='
    }

    [
      {
        field: primary_filter[:field].delete_prefix('cliente_contrato.'),
        value: primary_filter[:value],
        operator: primary_filter[:operator]
      },
      raw_filters
    ]
  end

  def in_filter(field, value)
    values = Array(value).compact_blank.map(&:to_s).uniq
    return if values.empty?

    {
      field: field,
      operator: values.one? ? '=' : 'IN',
      value: values.join(',')
    }
  end

  def exact_filter(field, value)
    { field: field, operator: '=', value: value }
  end
end

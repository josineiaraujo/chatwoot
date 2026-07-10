class Ibsoft::Erp::Adapters::Ixc::Search::ConcentratorClientSearch < Ibsoft::Erp::Adapters::Ixc::Search::BaseSearch
  def call(filters:, limit: DEFAULT_LIMIT, page: 1)
    limit = normalized_limit(limit)
    page = normalized_page(page)
    filters = filters.to_h.with_indifferent_access
    pppoe_filters = pppoe_filter_options(filters)
    return empty_result(page, limit) unless pppoe_filters?(pppoe_filters)

    records, total = pppoe_records(pppoe_filters)
    client_ids = records.pluck('id_cliente').compact_blank.uniq
    customers = client_batch_fetcher.call(
      client_ids: paged_client_ids(client_ids, page, limit),
      active: filters[:client_active],
      source: 'concentrators'
    )

    search_result(
      customers,
      source: { records: records, total: total, client_ids: client_ids },
      pagination: { page: page, limit: limit }
    )
  end

  def call_all(filters:)
    filters = filters.to_h.with_indifferent_access
    pppoe_filters = pppoe_filter_options(filters)
    return empty_result(1, DEFAULT_LIMIT) unless pppoe_filters?(pppoe_filters)

    records, total = pppoe_records(pppoe_filters)
    client_ids = records.pluck('id_cliente').compact_blank.uniq
    customers = client_batch_fetcher.call(
      client_ids: client_ids,
      active: filters[:client_active],
      source: 'concentrators'
    )

    complete_result(customers, source_total: total, source_returned: records.size)
  end

  private

  def search_result(customers, source:, pagination:)
    Ibsoft::Erp::CustomerSearchResult.new(
      customers: customers,
      source_total: source[:total],
      source_returned: source[:records].size,
      has_more: more?(source, pagination),
      pagination: { page: pagination[:page], per_page: pagination[:limit] }
    )
  end

  def more?(source, pagination)
    source[:total] > source[:records].size ||
      source[:client_ids].size > pagination[:page] * pagination[:limit]
  end

  def paged_client_ids(client_ids, page, limit)
    client_ids.slice(page_offset(page, limit), limit) || []
  end

  def pppoe_records(pppoe_filters)
    records = []
    total = 0
    page = 1

    loop do
      response = client.list('radusuarios', pppoe_payload(pppoe_filters, page))
      total = response.total
      records.concat(response.records)
      break if records.size >= total
      break if records.size >= MAX_SOURCE_RECORDS
      break if response.records.empty?

      page += 1
    end

    [records, total]
  end

  def pppoe_payload(pppoe_filters, page)
    primary_filter, additional_filters = split_pppoe_filters(pppoe_filters)

    Ibsoft::Erp::Adapters::Ixc::QueryBuilder.payload(
      table: 'radusuarios',
      field: primary_filter[:field],
      query: primary_filter[:value],
      operator: primary_filter[:operator],
      page: page,
      per_page: SOURCE_PAGE_SIZE,
      sort_field: 'radusuarios.id',
      sort_order: 'desc',
      filters: additional_filters
    )
  end

  def pppoe_filter_options(filters)
    {
      concentrator_ids: list_values(filters[:concentrator_ids]),
      transmitter_ids: resolved_transmitter_ids(filters),
      transmission_interface_ids: list_values(filters[:transmission_interface_ids]),
      ftth_box_ids: list_values(filters[:ftth_box_ids]),
      transmitter_port_ids: list_values(filters[:transmitter_port_ids])
    }
  end

  def pppoe_filters?(pppoe_filters)
    pppoe_filters.values.any?(&:present?)
  end

  def split_pppoe_filters(pppoe_filters)
    raw_filters = [
      in_filter('radusuarios.id_concentrador', pppoe_filters[:concentrator_ids]),
      in_filter('radusuarios.id_transmissor', pppoe_filters[:transmitter_ids]),
      in_filter('radusuarios.interface_transmissao', pppoe_filters[:transmission_interface_ids]),
      in_filter('radusuarios.id_caixa_ftth', pppoe_filters[:ftth_box_ids]),
      in_filter('radusuarios.id_porta_transmissor', pppoe_filters[:transmitter_port_ids]),
      { field: 'radusuarios.ativo', operator: '=', value: 'S' }
    ].compact
    primary_filter = raw_filters.shift

    [
      {
        field: primary_filter[:field].delete_prefix('radusuarios.'),
        value: primary_filter[:value],
        operator: primary_filter[:operator]
      },
      raw_filters
    ]
  end

  def resolved_transmitter_ids(filters)
    selected_ids = list_values(filters[:transmitter_ids])
    pop_ids = list_values(filters[:pop_ids])
    return selected_ids if pop_ids.empty?

    pop_transmitter_ids = transmitter_ids_for_pop_ids(pop_ids)
    return ['-1'] if pop_transmitter_ids.empty?
    return pop_transmitter_ids if selected_ids.empty?

    (selected_ids & pop_transmitter_ids).presence || ['-1']
  end

  def transmitter_ids_for_pop_ids(pop_ids)
    records = []
    page = 1

    loop do
      response = client.list('radpop_radio', transmitters_by_pop_payload(pop_ids, page))
      records.concat(response.records)
      break if records.size >= response.total
      break if records.size >= MAX_SOURCE_RECORDS
      break if response.records.empty?

      page += 1
    end

    records.pluck('id').compact_blank.map(&:to_s).uniq
  end

  def transmitters_by_pop_payload(pop_ids, page)
    Ibsoft::Erp::Adapters::Ixc::QueryBuilder.payload(
      table: 'radpop_radio',
      field: 'id_pop',
      query: array_query(pop_ids),
      operator: pop_ids.one? ? '=' : 'IN',
      page: page,
      per_page: SOURCE_PAGE_SIZE,
      sort_field: 'radpop_radio.id',
      sort_order: 'desc'
    )
  end

  def in_filter(field, value)
    values = list_values(value)
    return if values.empty?

    {
      field: field,
      value: values.join(','),
      operator: values.one? ? '=' : 'IN'
    }
  end

  def list_values(value)
    Array(value).flat_map { |item| item.to_s.split(',') }
                .map(&:strip)
                .compact_blank
                .uniq
  end

  def empty_result(page, limit)
    Ibsoft::Erp::CustomerSearchResult.new(
      customers: [],
      source_total: 0,
      source_returned: 0,
      has_more: false,
      pagination: { page: page, per_page: limit }
    )
  end
end

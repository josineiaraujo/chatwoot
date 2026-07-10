class Ibsoft::Erp::Adapters::Ixc::Search::DirectClientSearch < Ibsoft::Erp::Adapters::Ixc::Search::BaseSearch
  FILTERS = {
    name: { field: 'razao', operator: 'L' },
    street: { field: 'endereco', operator: 'L' },
    neighborhood: { field: 'bairro', operator: 'L' },
    zip_code: { field: 'cep', operator: '=' },
    city_id: { field: 'cidade', operator: '=' },
    state_id: { field: 'uf', operator: '=' },
    active: { field: 'ativo', operator: '=' }
  }.freeze

  def call(filters:, limit: DEFAULT_LIMIT, page: 1)
    limit = normalized_limit(limit)
    page = normalized_page(page)
    payload = client_payload(filters.to_h.with_indifferent_access, limit, page)
    response = client.list('cliente', payload)
    customers = mapper.map_records(response.records, source: 'direct')

    Ibsoft::Erp::CustomerSearchResult.new(
      customers: customers,
      source_total: response.total,
      source_returned: response.records.size,
      has_more: response.total > page * limit,
      pagination: { page: page, per_page: limit }
    )
  end

  def call_all(filters:)
    filters = filters.to_h.with_indifferent_access
    state = { customers: [], returned: 0, total: 0, page: 1 }

    loop do
      response = append_direct_page(state, filters)
      break if response.records.empty?
      break if state[:total].positive? && state[:returned] >= state[:total]
      break if state[:returned] >= MAX_SOURCE_RECORDS

      state[:page] += 1
    end

    complete_result(state[:customers].uniq(&:external_id), source_total: state[:total], source_returned: state[:returned])
  end

  private

  def append_direct_page(state, filters)
    response = client.list('cliente', client_payload(filters, DEFAULT_LIMIT, state[:page]))
    state[:total] = response.total
    state[:returned] += response.records.size
    state[:customers].concat(mapper.map_records(response.records, source: 'direct'))
    response
  end

  def client_payload(filters, limit, page)
    primary_filter, additional_filters = split_filters(filters)

    Ibsoft::Erp::Adapters::Ixc::QueryBuilder.payload(
      table: 'cliente',
      field: primary_filter[:field],
      query: primary_filter[:value],
      operator: primary_filter[:operator],
      page: page,
      per_page: limit,
      sort_field: 'cliente.id',
      sort_order: 'desc',
      filters: additional_filters
    )
  end

  def split_filters(filters)
    normalized_filters = normalized_filters(filters)

    primary_filter = normalized_filters.shift || {
      field: 'cliente.id',
      value: '1',
      operator: '>='
    }

    [
      {
        field: primary_filter[:field].delete_prefix('cliente.'),
        value: primary_filter[:value],
        operator: primary_filter[:operator]
      },
      normalized_filters
    ]
  end

  def normalized_filters(filters)
    FILTERS.filter_map do |key, definition|
      normalized_filter(key, definition, filters[key])
    end
  end

  def normalized_filter(key, definition, value)
    return if value.blank?

    value = active_value(value) if key == :active
    {
      field: "cliente.#{definition[:field]}",
      value: value,
      operator: definition[:operator]
    }
  end

  def mapper
    @mapper ||= Ibsoft::Erp::Adapters::Ixc::CustomerMapper.new(lookups)
  end
end

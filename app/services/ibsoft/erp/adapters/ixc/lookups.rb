class Ibsoft::Erp::Adapters::Ixc::Lookups
  DEFAULT_LIMIT = 50
  BRAZIL_COUNTRY_ID = '2'.freeze

  def initialize(client)
    @client = client
  end

  def states(query: nil, limit: DEFAULT_LIMIT)
    payload = if query.present?
                state_query_payload(query, limit)
              else
                Ibsoft::Erp::Adapters::Ixc::QueryBuilder.payload(
                  table: 'uf',
                  field: 'id_pais',
                  query: BRAZIL_COUNTRY_ID,
                  operator: '=',
                  per_page: limit,
                  sort_field: 'uf.nome'
                )
              end

    client.list('uf', payload).records.map { |record| normalize_state(record) }
  end

  def cities(state_id:, query: nil, limit: DEFAULT_LIMIT)
    client.list('cidade', city_payload(state_id, query, limit)).records.map { |record| normalize_city(record) }
  end

  def plans(query: nil, active: nil, limit: DEFAULT_LIMIT)
    filters = []
    filters << { field: 'vd_contratos.Ativo', operator: '=', value: active_value(active) } unless active.nil?

    payload = Ibsoft::Erp::Adapters::Ixc::QueryBuilder.payload(
      table: 'vd_contratos',
      field: query.present? ? 'nome' : 'id',
      query: query.presence || '1',
      operator: query.present? ? 'L' : '>=',
      per_page: limit,
      sort_field: 'vd_contratos.nome',
      filters: filters
    )

    client.list('vd_contratos', payload).records.map { |record| normalize_plan(record) }
  end

  def pops(query: nil, limit: DEFAULT_LIMIT)
    payload = Ibsoft::Erp::Adapters::Ixc::QueryBuilder.payload(
      table: 'radpop',
      field: query.present? ? 'pop' : 'id',
      query: query.presence || '1',
      operator: query.present? ? 'L' : '>=',
      per_page: limit,
      sort_field: 'radpop.pop'
    )

    client.list('radpop', payload).records
          .map { |record| normalize_pop(record) }
          .reject { |record| record[:id].blank? || record[:id] == '0' }
  end

  def transmitters(query: nil, limit: DEFAULT_LIMIT)
    Transmitters.new(client).call(query: query, limit: limit)
  end

  def cities_by_ids(city_ids)
    ids = Array(city_ids).compact_blank.map(&:to_s).uniq
    return {} if ids.empty?

    payload = Ibsoft::Erp::Adapters::Ixc::QueryBuilder.payload(
      table: 'cidade',
      field: 'id',
      query: ids.join(','),
      operator: 'IN',
      per_page: ids.size,
      sort_field: 'cidade.id'
    )

    client.list('cidade', payload).records.index_by { |record| record['id'].to_s }.transform_values { |record| normalize_city(record) }
  end

  def states_by_ids(state_ids)
    ids = Array(state_ids).compact_blank.map(&:to_s).uniq
    return {} if ids.empty?

    payload = Ibsoft::Erp::Adapters::Ixc::QueryBuilder.payload(
      table: 'uf',
      field: 'id',
      query: ids.join(','),
      operator: 'IN',
      per_page: ids.size,
      sort_field: 'uf.id',
      filters: brazil_country_filters
    )

    client.list('uf', payload).records
          .index_by { |record| record['id'].to_s }
          .transform_values { |record| normalize_state(record) }
  end

  private

  attr_reader :client

  def state_query_payload(query, limit)
    normalized_query = query.to_s.strip
    operator = normalized_query.length <= 2 ? '=' : 'L'
    field = normalized_query.length <= 2 ? 'sigla' : 'nome'

    Ibsoft::Erp::Adapters::Ixc::QueryBuilder.payload(
      table: 'uf',
      field: field,
      query: normalized_query,
      operator: operator,
      per_page: limit,
      sort_field: 'uf.nome',
      filters: brazil_country_filters
    )
  end

  def city_payload(state_id, query, limit)
    return city_query_payload(state_id, query, limit) if query.present?

    Ibsoft::Erp::Adapters::Ixc::QueryBuilder.payload(
      table: 'cidade',
      field: state_id.present? ? 'uf' : 'id',
      query: state_id.presence || '1',
      operator: state_id.present? ? '=' : '>=',
      per_page: limit,
      sort_field: 'cidade.nome'
    )
  end

  def city_query_payload(state_id, query, limit)
    filters = []
    filters << { field: 'cidade.uf', operator: '=', value: state_id } if state_id.present?

    Ibsoft::Erp::Adapters::Ixc::QueryBuilder.payload(
      table: 'cidade',
      field: 'nome',
      query: query,
      operator: 'L',
      per_page: limit,
      sort_field: 'cidade.nome',
      filters: filters
    )
  end

  def active_value(value)
    ActiveModel::Type::Boolean.new.cast(value) ? 'S' : 'N'
  end

  def brazil_country_filters
    [{ field: 'uf.id_pais', operator: '=', value: BRAZIL_COUNTRY_ID }]
  end

  def normalize_state(record)
    {
      id: record['id'].to_s,
      name: record['nome'].to_s,
      abbreviation: record['sigla'].to_s
    }
  end

  def normalize_city(record)
    {
      id: record['id'].to_s,
      name: record['nome'].to_s,
      state_id: record['uf'].to_s,
      ibge_code: record['cod_ibge'].to_s
    }
  end

  def normalize_plan(record)
    {
      id: record['id'].to_s,
      name: record['nome'].to_s,
      active: record['Ativo'].to_s == 'S',
      price: record['valor_contrato'].to_s
    }
  end

  def normalize_pop(record)
    {
      id: record['id'].to_s,
      name: record['pop'].to_s,
      city_id: record['id_cidade'].to_s,
      zip_code: record['cep'].to_s
    }
  end
end

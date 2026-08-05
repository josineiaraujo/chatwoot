class Ibsoft::Erp::Adapters::Sgp::Lookups
  DEFAULT_LIMIT = 50
  CACHE_TTL = 15.minutes
  BRAZILIAN_STATES = {
    'AC' => 'Acre', 'AL' => 'Alagoas', 'AP' => 'Amapá', 'AM' => 'Amazonas',
    'BA' => 'Bahia', 'CE' => 'Ceará', 'DF' => 'Distrito Federal',
    'ES' => 'Espírito Santo', 'GO' => 'Goiás', 'MA' => 'Maranhão',
    'MT' => 'Mato Grosso', 'MS' => 'Mato Grosso do Sul', 'MG' => 'Minas Gerais',
    'PA' => 'Pará', 'PB' => 'Paraíba', 'PR' => 'Paraná', 'PE' => 'Pernambuco',
    'PI' => 'Piauí', 'RJ' => 'Rio de Janeiro', 'RN' => 'Rio Grande do Norte',
    'RS' => 'Rio Grande do Sul', 'RO' => 'Rondônia', 'RR' => 'Roraima',
    'SC' => 'Santa Catarina', 'SP' => 'São Paulo', 'SE' => 'Sergipe',
    'TO' => 'Tocantins'
  }.freeze

  def initialize(client)
    @client = client
  end

  def states(query: nil, limit: DEFAULT_LIMIT)
    filtered = BRAZILIAN_STATES.keys.filter_map { |state| normalized_state(state) }
    filtered = filter_by_query(filtered, query, :name, :abbreviation)
    filtered.first(normalized_limit(limit))
  end

  def cities(**)
    []
  end

  def plans(query: nil, active: nil, limit: DEFAULT_LIMIT)
    records = cached('plans') { client.plans.records }.map { |record| normalized_plan(record) }
    records = records.select { |record| record[:active] == ActiveModel::Type::Boolean.new.cast(active) } unless active.nil?
    filter_by_query(records, query, :name).first(normalized_limit(limit))
  end

  def pops(query: nil, limit: DEFAULT_LIMIT)
    records = cached('pops') { client.pops.records }.map { |record| normalized_pop(record) }
    filter_by_query(records, query, :name).first(normalized_limit(limit))
  end

  def transmitters(query: nil, limit: DEFAULT_LIMIT)
    records = all_transmitters
    filter_by_query(records, query, :name, :ip, :identifier).first(normalized_limit(limit))
  end

  def transmitters_by_ids(ids)
    requested_ids = Array(ids).compact_blank.map(&:to_s).uniq
    all_transmitters.select { |record| requested_ids.include?(record[:id]) }
  end

  private

  attr_reader :client

  def normalized_state(state)
    abbreviation = state.to_s.upcase
    name = BRAZILIAN_STATES[abbreviation]
    return if name.blank?

    { id: abbreviation, name: name, abbreviation: abbreviation }
  end

  def normalized_plan(raw_record)
    record = raw_record.to_h.with_indifferent_access
    {
      id: record[:id].to_s,
      name: record[:descricao].presence || record[:description].presence || record[:nome].to_s,
      active: normalized_active(record),
      price: (record[:preco].presence || record[:price]).to_s
    }
  end

  def normalized_pop(raw_record)
    record = raw_record.to_h.with_indifferent_access
    { id: record[:id].to_s, name: record[:pop].to_s }
  end

  def all_transmitters
    cached('nas') { client.nas.records }.map { |record| normalized_transmitter(record) }
  end

  def normalized_transmitter(raw_record)
    record = raw_record.to_h.with_indifferent_access
    {
      id: record[:id].to_s,
      name: first_value(record, :descricao, :description, :identificador, :identifier),
      identifier: first_value(record, :identificador, :identifier),
      ip: first_value(record, :endereco_ip, :ip, :IP),
      active: normalized_active(record),
      pop_ids: pop_ids(record)
    }
  end

  def first_value(record, *keys)
    keys.filter_map { |key| record[key].presence }.first.to_s
  end

  def pop_ids(record)
    Array(record[:pops]).filter_map { |pop| pop.to_h.with_indifferent_access[:id]&.to_s }
  end

  def normalized_active(record)
    value = if record.key?(:ativo)
              record[:ativo]
            elsif record.key?(:active)
              record[:active]
            end
    return true if value.nil?

    ActiveModel::Type::Boolean.new.cast(value)
  end

  def filter_by_query(records, query, *fields)
    normalized_query = normalized_text(query)
    return records if normalized_query.blank?

    records.select do |record|
      fields.any? { |field| normalized_text(record[field]).include?(normalized_query) }
    end
  end

  def normalized_text(value)
    I18n.transliterate(value.to_s).downcase.strip
  end

  def normalized_limit(value)
    requested = value.to_i
    requested = DEFAULT_LIMIT unless requested.positive?
    [requested, 100].min
  end

  def cached(key, &)
    Rails.cache.fetch(cache_key(key), expires_in: CACHE_TTL, &)
  end

  def cache_key(key)
    connection = client.connection
    "ibsoft:erp:sgp:lookups:v1:#{connection.id}:#{connection.updated_at.to_i}:#{key}"
  end
end

class Ibsoft::Erp::Adapters::Ixc::ClientBatchFetcher
  BATCH_SIZE = 100

  def initialize(client, lookups: nil)
    @client = client
    @lookups = lookups || Ibsoft::Erp::Adapters::Ixc::Lookups.new(client)
  end

  def call(client_ids:, active: nil, location: {}, limit: nil, source: 'ixc')
    location = location.with_indifferent_access
    normalized_ids = Array(client_ids).compact_blank.map(&:to_s).uniq
    normalized_ids = normalized_ids.first(limit.to_i) if limit.present?
    records = normalized_ids.each_slice(BATCH_SIZE).flat_map do |ids|
      fetch_batch(
        ids,
        active: active,
        city_id: location[:city_id],
        state_id: location[:state_id]
      )
    end

    mapper.map_records(records, source: source)
  end

  private

  attr_reader :client, :lookups

  def fetch_batch(ids, active:, city_id:, state_id:)
    filters = []
    filters << { field: 'cliente.ativo', operator: '=', value: active_value(active) } unless active.nil?
    filters << { field: 'cliente.cidade', operator: '=', value: city_id } if city_id.present?
    filters << { field: 'cliente.uf', operator: '=', value: state_id } if state_id.present?

    payload = Ibsoft::Erp::Adapters::Ixc::QueryBuilder.payload(
      table: 'cliente',
      field: 'id',
      query: ids.join(','),
      operator: 'IN',
      per_page: ids.size,
      sort_field: 'cliente.id',
      sort_order: 'desc',
      filters: filters
    )

    client.list('cliente', payload).records
  end

  def mapper
    @mapper ||= Ibsoft::Erp::Adapters::Ixc::CustomerMapper.new(lookups)
  end

  def active_value(value)
    ActiveModel::Type::Boolean.new.cast(value) ? 'S' : 'N'
  end
end

class Ibsoft::Erp::Adapters::Ixc::Lookups::Transmitters
  def initialize(client)
    @client = client
  end

  def call(query:, limit:)
    client.list('radpop_radio', payload(query, limit)).records
          .map { |record| normalize(record) }
          .reject { |record| record[:id].blank? || record[:id] == '0' }
  end

  private

  attr_reader :client

  def payload(query, limit)
    Ibsoft::Erp::Adapters::Ixc::QueryBuilder.payload(
      table: 'radpop_radio',
      field: query.present? ? 'descricao' : 'id',
      query: query.presence || '1',
      operator: query.present? ? 'L' : '>=',
      per_page: limit,
      sort_field: 'radpop_radio.descricao'
    )
  end

  def normalize(record)
    {
      id: record['id'].to_s,
      name: record['descricao'].presence || record['nome'].presence || record['ip'].to_s,
      pop_id: record['id_pop'].to_s,
      ip: record['ip'].to_s,
      active: record['ativo'].to_s == 'S'
    }
  end
end

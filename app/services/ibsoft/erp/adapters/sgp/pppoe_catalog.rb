class Ibsoft::Erp::Adapters::Sgp::PppoeCatalog
  PAGE_SIZE = 1000
  MAX_SOURCE_RECORDS = 10_000

  Result = Struct.new(:records, :source_total, :source_returned, keyword_init: true)

  def initialize(client)
    @client = client
  end

  def call(pop_ids:, nas_ips:)
    records = []
    source_total = 0

    request_scopes(pop_ids, nas_ips).each do |scope|
      scoped_records, scoped_total = fetch_scope(scope)
      records.concat(scoped_records)
      source_total += scoped_total
      break if records.size >= MAX_SOURCE_RECORDS
    end

    records = deduplicated_records(records).first(MAX_SOURCE_RECORDS)
    Result.new(
      records: records,
      source_total: [source_total, records.size].max,
      source_returned: records.size
    )
  end

  private

  attr_reader :client

  def request_scopes(pop_ids, nas_ips)
    pops = Array(pop_ids).compact_blank.map(&:to_s).uniq
    nas = Array(nas_ips).compact_blank.map(&:to_s).uniq
    return pops.map { |pop_id| { pop: pop_id } } if pops.any?
    return nas.map { |ip| { nas: ip } } if nas.any?

    [{}]
  end

  def fetch_scope(scope)
    records = []
    total = 0

    loop do
      response = client.pppoe(
        scope.merge(offset: records.size, limit: PAGE_SIZE, last_session: true)
      )
      total = response.total
      records.concat(response.records)
      break if response.records.empty? || records.size >= total || records.size >= MAX_SOURCE_RECORDS
    end

    [records, total]
  end

  def deduplicated_records(records)
    records.uniq do |record|
      normalized = record.to_h.with_indifferent_access
      [normalized[:servico_id], normalized[:pppoe_login]]
    end
  end
end

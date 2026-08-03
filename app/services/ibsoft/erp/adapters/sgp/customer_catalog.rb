class Ibsoft::Erp::Adapters::Sgp::CustomerCatalog
  PAGE_SIZE = 100
  MAX_SOURCE_RECORDS = 10_000

  Result = Struct.new(:records, :source_total, :source_returned, keyword_init: true)

  def initialize(client)
    @client = client
  end

  def call(filters: {}, include_contracts: true)
    records = []
    total = 0

    loop do
      response = client.customers(
        request_payload(filters, records.size, include_contracts)
      )
      total = response.total
      records.concat(response.records)
      break if source_complete?(records, response, total)
    end

    Result.new(
      records: records.first(MAX_SOURCE_RECORDS),
      source_total: total,
      source_returned: records.size
    )
  end

  private

  attr_reader :client

  def request_payload(filters, offset, include_contracts)
    payload = filters.to_h.compact_blank.merge(
      offset: offset,
      limit: PAGE_SIZE,
      omitir_titulos: true
    )
    payload[:omitir_contratos] = true unless include_contracts
    payload
  end

  def source_complete?(records, response, total)
    response.records.empty? ||
      records.size >= total ||
      records.size >= MAX_SOURCE_RECORDS
  end
end

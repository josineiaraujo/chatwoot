class Ibsoft::Erp::Adapters::Sgp::CustomerSearch
  MODES = {
    'direct' => Ibsoft::Erp::Adapters::Sgp::Search::DirectClientSearch,
    'contracts' => Ibsoft::Erp::Adapters::Sgp::Search::ContractClientSearch,
    'concentrators' => Ibsoft::Erp::Adapters::Sgp::Search::ConcentratorClientSearch
  }.freeze

  def initialize(connection)
    @client = Ibsoft::Erp::Adapters::Sgp::Client.new(connection)
    @lookups = Ibsoft::Erp::Adapters::Sgp::Lookups.new(client)
  end

  def call(mode:, filters:, limit: nil, page: nil)
    search(mode).call(filters: filters, limit: limit, page: page)
  end

  def call_all(mode:, filters:)
    search(mode).call_all(filters: filters)
  end

  private

  attr_reader :client, :lookups

  def search(mode)
    MODES.fetch(mode.to_s).new(client, lookups: lookups)
  end
end

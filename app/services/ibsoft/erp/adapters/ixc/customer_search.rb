class Ibsoft::Erp::Adapters::Ixc::CustomerSearch
  MODES = {
    'direct' => Ibsoft::Erp::Adapters::Ixc::Search::DirectClientSearch,
    'contracts' => Ibsoft::Erp::Adapters::Ixc::Search::ContractClientSearch,
    'concentrators' => Ibsoft::Erp::Adapters::Ixc::Search::ConcentratorClientSearch
  }.freeze

  def initialize(connection)
    @client = Ibsoft::Erp::Adapters::Ixc::Client.new(connection)
    @lookups = Ibsoft::Erp::Adapters::Ixc::Lookups.new(@client)
  end

  def call(mode:, filters:, limit: nil, page: nil)
    search_class = MODES.fetch(mode.to_s)
    search_class.new(client, lookups: lookups).call(
      filters: filters,
      limit: limit,
      page: page
    )
  end

  def call_all(mode:, filters:)
    search_class = MODES.fetch(mode.to_s)
    search_class.new(client, lookups: lookups).call_all(filters: filters)
  end

  private

  attr_reader :client, :lookups
end

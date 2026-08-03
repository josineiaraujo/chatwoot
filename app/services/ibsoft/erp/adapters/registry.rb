class Ibsoft::Erp::Adapters::Registry
  PROVIDERS = {
    'ixc' => {
      client: Ibsoft::Erp::Adapters::Ixc::Client,
      lookups: Ibsoft::Erp::Adapters::Ixc::Lookups,
      search: Ibsoft::Erp::Adapters::Ixc::CustomerSearch,
      capabilities: {
        search_modes: %w[direct contracts concentrators],
        contract_filters: { internet_status: true },
        concentrator_filters: {
          manual_concentrator_ids: true,
          pops: true,
          transmitters: true,
          transmission_interfaces: true,
          ftth_boxes: true,
          transmitter_ports: true,
          transmitter_kind: 'transmitter'
        }
      }
    },
    'sgp' => {
      client: Ibsoft::Erp::Adapters::Sgp::Client,
      lookups: Ibsoft::Erp::Adapters::Sgp::Lookups,
      search: Ibsoft::Erp::Adapters::Sgp::CustomerSearch,
      capabilities: {
        search_modes: %w[direct contracts concentrators],
        contract_filters: { internet_status: false },
        concentrator_filters: {
          manual_concentrator_ids: false,
          pops: true,
          transmitters: true,
          transmission_interfaces: false,
          ftth_boxes: false,
          transmitter_ports: true,
          transmitter_kind: 'nas'
        }
      }
    }
  }.freeze

  class << self
    def supports_search?(provider)
      definition(provider)&.key?(:search) || false
    end

    def search(connection)
      definition!(connection.provider).fetch(:search).new(connection)
    end

    def lookups(connection)
      provider = definition!(connection.provider)
      provider.fetch(:lookups).new(provider.fetch(:client).new(connection))
    end

    def capabilities(provider)
      definition!(provider).fetch(:capabilities).deep_dup
    end

    private

    def definition(provider)
      PROVIDERS[provider.to_s]
    end

    def definition!(provider)
      PROVIDERS.fetch(provider.to_s)
    end
  end
end

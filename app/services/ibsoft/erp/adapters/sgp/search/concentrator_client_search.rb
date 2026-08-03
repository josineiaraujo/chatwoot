class Ibsoft::Erp::Adapters::Sgp::Search::ConcentratorClientSearch < Ibsoft::Erp::Adapters::Sgp::Search::BaseSearch
  def call(filters:, limit: DEFAULT_LIMIT, page: 1)
    paged_result(call_all(filters: filters), limit, page)
  end

  def call_all(filters:)
    filters = filters.to_h.with_indifferent_access
    return empty_result unless infrastructure_filter?(filters)

    nas_ips = selected_nas_ips(filters[:transmitter_ids])
    return empty_result if list_values(filters[:transmitter_ids]).any? && nas_ips.empty?

    source = pppoe_catalog.call(pop_ids: list_values(filters[:pop_ids]), nas_ips: nas_ips)
    pppoe_records = filter_pppoe_records(source.records, filters, nas_ips)
    identifiers = pppoe_identifiers(pppoe_records)
    customers = customers_for_pppoe(identifiers, filters)

    complete_result(
      customers,
      source_total: source.source_total,
      source_returned: source.source_returned
    )
  end

  private

  def infrastructure_filter?(filters)
    %i[pop_ids transmitter_ids transmitter_port_ids].any? do |key|
      list_values(filters[key]).any?
    end
  end

  def selected_nas_ips(ids)
    lookups.transmitters_by_ids(list_values(ids)).pluck(:ip).compact_blank.uniq
  end

  def filter_pppoe_records(records, filters, nas_ips)
    expected_ports = list_values(filters[:transmitter_port_ids])

    records.select do |raw_record|
      sessions = Array(raw_record.to_h.with_indifferent_access[:radacct]).map(&:with_indifferent_access)
      nas_matches?(sessions, nas_ips) && port_matches?(sessions, expected_ports)
    end
  end

  def nas_matches?(sessions, nas_ips)
    nas_ips.empty? || sessions.any? { |session| nas_ips.include?(session[:nasipaddress].to_s) }
  end

  def port_matches?(sessions, expected_ports)
    expected_ports.empty? || sessions.any? { |session| expected_ports.include?(session[:nasportid].to_s) }
  end

  def pppoe_identifiers(records)
    records.each_with_object({ service_ids: [], logins: [] }) do |raw_record, result|
      record = raw_record.to_h.with_indifferent_access
      result[:service_ids] << record[:servico_id].to_s if record[:servico_id].present?
      result[:logins] << normalized_text(record[:pppoe_login]) if record[:pppoe_login].present?
    end.transform_values(&:uniq)
  end

  def customers_for_pppoe(identifiers, filters)
    return [] if identifiers.values.all?(&:empty?)

    source = customer_catalog.call(include_contracts: true)
    matching_records = source.records.select do |record|
      customer_matches_pppoe?(record, identifiers)
    end
    filter_customers(mapper.map_records(matching_records, source: 'concentrators'), filters)
  end

  def customer_matches_pppoe?(record, identifiers)
    services = customer_services(record)
    service_ids = services.filter_map { |service| service[:id]&.to_s }
    logins = services.filter_map do |service|
      normalized_text(service[:login]) if service[:login].present?
    end

    service_ids.intersect?(identifiers[:service_ids]) ||
      logins.intersect?(identifiers[:logins])
  end

  def customer_services(raw_record)
    Array(raw_record.to_h.with_indifferent_access[:contratos]).flat_map do |contract|
      Array(contract.to_h.with_indifferent_access[:servicos]).map(&:with_indifferent_access)
    end
  end

  def pppoe_catalog
    @pppoe_catalog ||= Ibsoft::Erp::Adapters::Sgp::PppoeCatalog.new(client)
  end

  def empty_result
    complete_result([], source_total: 0, source_returned: 0)
  end
end

class Ibsoft::Erp::Adapters::Sgp::Search::ContractClientSearch < Ibsoft::Erp::Adapters::Sgp::Search::BaseSearch
  CONTRACT_STATUS_CODES = {
    '1' => %w[1 ativo],
    '2' => %w[2 inativo],
    '3' => %w[3 cancelado],
    '4' => %w[4 suspenso],
    '5' => ['5', 'inviabilidade tecnica'],
    '6' => %w[6 novo],
    '7' => ['7', 'reduzido', 'ativo v. reduzida', 'ativo v. reduzia'],
    'A' => %w[1 7],
    'I' => ['2'],
    'P' => ['6'],
    'D' => ['3']
  }.freeze

  def call(filters:, limit: DEFAULT_LIMIT, page: 1)
    paged_result(call_all(filters: filters), limit, page)
  end

  def call_all(filters:)
    filters = filters.to_h.with_indifferent_access
    source = customer_catalog.call(include_contracts: true)
    matching_records = source.records.select { |record| contract_matches?(record, filters) }
    customers = mapper.map_records(matching_records, source: 'contracts')
    customers = filter_customers(customers, filters)

    complete_result(
      customers,
      source_total: source.source_total,
      source_returned: source.source_returned
    )
  end

  private

  def contract_matches?(raw_record, filters)
    contracts = Array(raw_record.to_h.with_indifferent_access[:contratos])
    return false if contracts.empty?

    contracts.any? do |raw_contract|
      contract = raw_contract.to_h.with_indifferent_access
      status_matches?(contract[:status], filters[:contract_statuses]) &&
        plan_matches?(contract, filters[:plan_ids])
    end
  end

  def status_matches?(status, selected_statuses)
    expected_codes = list_values(selected_statuses).flat_map do |selected_status|
      CONTRACT_STATUS_CODES.fetch(selected_status, [selected_status])
    end
    return true if expected_codes.empty?

    expected_codes.map { |value| normalized_text(value) }.include?(normalized_text(status)) ||
      expected_codes.include?(status_code(status))
  end

  def status_code(status)
    normalized_status = normalized_text(status)
    CONTRACT_STATUS_CODES.find do |code, aliases|
      code.match?(/\A\d\z/) && aliases.map { |value| normalized_text(value) }.include?(normalized_status)
    end&.first
  end

  def plan_matches?(contract, selected_plan_ids)
    expected_ids = list_values(selected_plan_ids)
    return true if expected_ids.empty?

    contract_plan_ids = Array(contract[:servicos]).filter_map do |service|
      service.to_h.with_indifferent_access.dig(:plano, :id)&.to_s
    end
    contract_plan_ids.intersect?(expected_ids)
  end
end

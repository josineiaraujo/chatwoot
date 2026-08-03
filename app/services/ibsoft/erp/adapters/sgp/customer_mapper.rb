class Ibsoft::Erp::Adapters::Sgp::CustomerMapper
  ACTIVE_CONTRACT_STATUSES = [
    '1', '7', 'ativo', 'reduzido', 'ativo v. reduzida', 'ativo v. reduzia'
  ].freeze

  def map_records(records, source:)
    Array(records).map { |record| map_record(record.with_indifferent_access, source) }
  end

  private

  def map_record(record, source)
    address = record[:endereco].to_h.with_indifferent_access
    contracts = Array(record[:contratos]).map(&:with_indifferent_access)

    Ibsoft::Erp::NormalizedCustomer.new(customer_attributes(record, address, contracts, source))
  end

  def customer_attributes(record, address, contracts, source)
    identity_attributes(record).merge(
      location_attributes(address),
      contract_attributes(contracts),
      phone_candidates: phone_candidates(record[:contatos]),
      source: source
    )
  end

  def identity_attributes(record)
    {
      external_id: record[:id],
      name: record[:nome],
      document: record[:cpfcnpj]
    }
  end

  def location_attributes(address)
    {
      city_id: city_id(address),
      city_name: address[:cidade],
      state_id: normalized_state(address[:uf]),
      state: normalized_state(address[:uf]),
      zip_code: address[:cep],
      address: formatted_address(address),
      neighborhood: address[:bairro]
    }
  end

  def contract_attributes(contracts)
    {
      active: contracts.any? { |contract| active_contract?(contract[:status]) },
      contract_ids: contract_ids(contracts),
      plan_ids: plan_ids(contracts)
    }
  end

  def active_contract?(status)
    ACTIVE_CONTRACT_STATUSES.include?(normalized_text(status))
  end

  def normalized_text(value)
    I18n.transliterate(value.to_s).strip.downcase
  end

  def normalized_state(value)
    value.to_s.strip.upcase
  end

  def city_id(address)
    [normalized_state(address[:uf]), address[:cidade].to_s.strip].compact_blank.join('|')
  end

  def formatted_address(address)
    [address[:logradouro], address[:numero]].compact_blank.join(', ')
  end

  def contract_ids(contracts)
    contracts.filter_map { |contract| contract[:id].presence || contract[:contrato].presence }
  end

  def plan_ids(contracts)
    contracts.flat_map do |contract|
      Array(contract[:servicos]).filter_map do |service|
        service.to_h.with_indifferent_access.dig(:plano, :id)
      end
    end
  end

  def phone_candidates(contacts)
    normalized_contacts = contacts.to_h.with_indifferent_access
    cellular_candidates(normalized_contacts[:celulares]) +
      landline_candidates(normalized_contacts[:telefones])
  end

  def cellular_candidates(values)
    Array(values).each_with_index.filter_map do |value, index|
      phone = contact_value(value)
      next if phone.blank?

      { source: index.zero? ? 'whatsapp' : 'mobile', value: phone }
    end
  end

  def landline_candidates(values)
    Array(values).filter_map do |value|
      phone = contact_value(value)
      { source: 'landline', value: phone } if phone.present?
    end
  end

  def contact_value(value)
    return value unless value.respond_to?(:to_h)

    contact = value.to_h.with_indifferent_access
    contact[:numero].presence || contact[:telefone].presence ||
      contact[:valor].presence || contact[:value]
  end
end

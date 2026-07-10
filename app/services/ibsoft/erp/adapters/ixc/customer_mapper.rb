class Ibsoft::Erp::Adapters::Ixc::CustomerMapper
  def initialize(lookups)
    @lookups = lookups
  end

  def map_records(records, source:)
    records = Array(records)
    lookup_context = build_lookup_context(records)

    records.map { |record| map_record(record, source, lookup_context) }
  end

  private

  attr_reader :lookups

  def state_ids_from(records, cities_by_id)
    direct_state_ids = records.pluck('uf')
    city_state_ids = cities_by_id.values.pluck(:state_id)

    direct_state_ids.concat(city_state_ids).compact_blank.uniq
  end

  def build_lookup_context(records)
    cities_by_id = lookups.cities_by_ids(records.pluck('cidade'))

    {
      cities_by_id: cities_by_id,
      states_by_id: lookups.states_by_ids(state_ids_from(records, cities_by_id))
    }
  end

  def map_record(record, source, lookup_context)
    city = lookup_context[:cities_by_id][record['cidade'].to_s] || {}
    state_id = record['uf'].presence || city[:state_id]
    state = lookup_context[:states_by_id][state_id.to_s] || {}

    Ibsoft::Erp::NormalizedCustomer.new(
      base_customer_attributes(record, source).merge(
        city_name: city[:name],
        state_id: state_id,
        state: state[:abbreviation]
      )
    )
  end

  def base_customer_attributes(record, source)
    {
      external_id: record['id'],
      name: record['razao'],
      document: record['cnpj_cpf'],
      active: record['ativo'].to_s == 'S',
      city_id: record['cidade'],
      zip_code: record['cep'],
      address: record['endereco'],
      neighborhood: record['bairro'],
      phone_candidates: phone_candidates(record),
      source: source
    }
  end

  def phone_candidates(record)
    [
      { source: 'whatsapp', value: record['whatsapp'] },
      { source: 'mobile', value: record['telefone_celular'] },
      { source: 'landline', value: record['fone'] }
    ]
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::Erp::Adapters::Sgp::CustomerSearch do
  let(:account) { create(:account) }
  let(:connection) do
    create(
      :ibsoft_erp_connection,
      account: account,
      provider: 'sgp',
      auth_type: 'token_app',
      base_url: 'https://sgp.example.com.br',
      credentials: { app: 'sgp-app', token: 'sgp-token' },
      active: true
    )
  end

  it 'normalizes direct-search customers and keeps contracts in the SGP response' do
    request = stub_customer_page(
      records: [customer_record],
      total: 1,
      expected_body: {
        'offset' => '0',
        'limit' => '100',
        'cliente_nome' => 'cliente teste'
      },
      reject_body_keys: ['omitir_contratos']
    )

    result = described_class.new(connection).call_all(
      mode: 'direct',
      filters: {
        name: 'cliente teste',
        state_id: 'BA',
        city_id: 'BA|Salvador',
        active: true
      }
    )

    customer = result.customers.first
    expect(request).to have_been_requested.once
    expect(customer.payload).to include(
      external_id: '398',
      name: 'Cliente teste',
      active: true,
      city_id: 'BA|Salvador',
      city_name: 'Salvador',
      state: 'BA',
      contract_ids: ['44'],
      plan_ids: ['101']
    )
    expect(customer.phone_candidates).to eq(
      [
        { source: 'whatsapp', value: '(75) 99999-9999' },
        { source: 'mobile', value: '75988888888' },
        { source: 'landline', value: '7533334444' }
      ]
    )
  end

  it 'loads every SGP customer page in bounded batches instead of one request per customer' do
    first_page = Array.new(100) do |index|
      customer_record(id: index + 1, name: "Cliente #{index + 1}")
    end
    second_page = [customer_record(id: 101, name: 'Cliente 101')]
    first_request = stub_customer_page(
      records: first_page,
      total: 101,
      expected_body: { 'offset' => '0', 'limit' => '100' }
    )
    second_request = stub_customer_page(
      records: second_page,
      total: 101,
      expected_body: { 'offset' => '100', 'limit' => '100' }
    )

    result = described_class.new(connection).call_all(mode: 'direct', filters: {})

    expect(result.customers.size).to eq(101)
    expect(first_request).to have_been_requested.once
    expect(second_request).to have_been_requested.once
  end

  it 'filters SGP customers by contract status and plan using the shared semantics' do
    active_customer = customer_record
    inactive_customer = customer_record(
      id: 399,
      name: 'Cliente inativo',
      contract_status: '2',
      plan_id: 102
    )
    stub_customer_page(records: [active_customer, inactive_customer], total: 2)

    result = described_class.new(connection).call_all(
      mode: 'contracts',
      filters: {
        contract_statuses: ['A'],
        plan_ids: ['101'],
        client_active: true
      }
    )

    expect(result.customers.map(&:external_id)).to contain_exactly('398')
  end

  it 'joins NAS sessions to customers by the documented PPPoE login when service_id is absent' do
    nas_request = stub_nas_lookup
    pppoe_request = stub_pppoe_lookup
    customer_request = stub_customer_page(records: [customer_record], total: 1)

    result = described_class.new(connection).call_all(
      mode: 'concentrators',
      filters: {
        transmitter_ids: ['9'],
        transmitter_port_ids: ['pon-1'],
        client_active: true
      }
    )

    expect(result.customers.map(&:external_id)).to contain_exactly('398')
    expect(nas_request).to have_been_requested.once
    expect(pppoe_request).to have_been_requested.once
    expect(customer_request).to have_been_requested.once
  end

  def stub_customer_page(records:, total:, expected_body: nil, reject_body_keys: [])
    request = stub_request(:post, 'https://sgp.example.com.br/api/ura/clientes/')
    request.with do |web_request|
      customer_request_matches?(web_request, expected_body, reject_body_keys)
    end
    request.to_return(status: 200, body: customer_response(records, total).to_json, headers: json_headers)
  end

  def customer_record(id: 398, name: 'Cliente teste', contract_status: '1', plan_id: 101)
    {
      id: id,
      nome: name,
      cpfcnpj: '00000000000',
      endereco: customer_address,
      contatos: customer_contacts,
      contratos: [customer_contract(contract_status, plan_id)]
    }
  end

  def customer_request_matches?(request, expected_body, reject_body_keys)
    body = parsed_form(request)
    authenticated = body.slice('app', 'token') == { 'app' => 'sgp-app', 'token' => 'sgp-token' }
    expected = expected_body.blank? || expected_body.all? { |key, value| body[key] == value }
    rejected = reject_body_keys.none? { |key| body.key?(key) }

    authenticated && expected && rejected
  end

  def customer_response(records, total)
    offset = records.first&.dig(:id).to_i > 100 ? 100 : 0
    {
      clientes: records,
      paginacao: { limit: 100, total: total, offset: offset, parcial: records.size }
    }
  end

  def customer_address
    {
      uf: 'BA', cidade: 'Salvador', cep: '40000-000',
      logradouro: 'Rua de teste', numero: 10, bairro: 'Centro'
    }
  end

  def customer_contacts
    {
      celulares: [{ numero: '(75) 99999-9999' }, '75988888888'],
      telefones: [{ telefone: '7533334444' }]
    }
  end

  def customer_contract(status, plan_id)
    {
      contrato: 44,
      status: status,
      servicos: [{ id: 900, login: 'cliente398', plano: { id: plan_id, descricao: 'Fibra 600 Mega' } }]
    }
  end

  def stub_nas_lookup
    stub_request(:post, 'https://sgp.example.com.br/api/ura/nas/list/')
      .with { |request| authenticated_json?(request) }
      .to_return(status: 200, body: [nas_record].to_json, headers: json_headers)
  end

  def stub_pppoe_lookup
    stub_request(:post, 'https://sgp.example.com.br/ws/radius/radacct/list/all/')
      .with { |request| expected_pppoe_request?(request) }
      .to_return(status: 200, body: pppoe_response.to_json, headers: json_headers)
  end

  def authenticated_json?(request)
    JSON.parse(request.body).slice('app', 'token') == { 'app' => 'sgp-app', 'token' => 'sgp-token' }
  end

  def expected_pppoe_request?(request)
    parsed_form(request).slice('app', 'token', 'nas', 'offset', 'limit') == {
      'app' => 'sgp-app', 'token' => 'sgp-token', 'nas' => '192.0.2.9',
      'offset' => '0', 'limit' => '1000'
    }
  end

  def nas_record
    {
      id: 9, descricao: 'NAS principal', endereco_ip: '192.0.2.9',
      identificador: 'nas-9', pops: [{ id: 1 }]
    }
  end

  def pppoe_response
    {
      result: [{ pppoe_login: 'cliente398', radacct: [{ nasipaddress: '192.0.2.9', nasportid: 'pon-1' }] }],
      paggination: { total: 1, returned: 1, offset: 0, limit: 1000 }
    }
  end

  def parsed_form(request)
    Rack::Utils.parse_nested_query(request.body)
  end

  def json_headers
    { 'Content-Type' => 'application/json' }
  end
end

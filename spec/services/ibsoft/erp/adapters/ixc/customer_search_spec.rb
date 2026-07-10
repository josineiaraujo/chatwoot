require 'rails_helper'
require 'base64'

RSpec.describe Ibsoft::Erp::Adapters::Ixc::CustomerSearch do
  let(:account) { create(:account) }
  let(:connection) do
    create(
      :ibsoft_erp_connection,
      account: account,
      provider: 'ixc',
      auth_type: 'basic',
      base_url: 'https://ixc.example.com.br',
      credentials: { username: 'ixc_user', password: 'ixc_password' },
      active: true
    )
  end
  let(:auth_header) { "Basic #{Base64.strict_encode64('ixc_user:ixc_password')}" }

  before do
    stub_lookup_tables
  end

  it 'searches direct clients with contains and exact filters' do
    client_request = stub_ixc(
      'cliente',
      {
        registros: [
          {
            id: '4797',
            razao: 'Josinei Dos Anjos Araujo',
            cnpj_cpf: '00000000000',
            ativo: 'S',
            cidade: '1840',
            uf: '10',
            cep: '46830-000',
            endereco: 'Rua 1',
            bairro: 'Centro',
            whatsapp: '75982479788',
            telefone_celular: '75999999999',
            fone: ''
          }
        ],
        total: 1
      }
    )

    result = described_class.new(connection).call(
      mode: 'direct',
      filters: {
        name: 'josinei',
        city_id: '1840',
        active: true
      },
      limit: 20
    )

    expect(client_request).to have_been_requested
    expect_ixc_brazilian_state_lookup('10')
    expect(result.customers.first.payload).to include(
      external_id: '4797',
      name: 'Josinei Dos Anjos Araujo',
      city_name: 'Andaraí',
      state: 'BA'
    )
  end

  it 'loads all direct-search pages in bounded IXC batches' do
    first_page_records = Array.new(100) do |index|
      client_record((index + 1).to_s, "Cliente #{index + 1}")
    end
    second_page_records = [client_record('101', 'Cliente 101')]
    first_page_request = stub_request(:get, 'https://ixc.example.com.br/webservice/v1/cliente')
                         .with(
                           headers: { 'Authorization' => auth_header },
                           body: hash_including('page' => '1', 'rp' => '100')
                         )
                         .to_return(
                           status: 200,
                           body: { registros: first_page_records, total: 101 }.to_json,
                           headers: { 'Content-Type' => 'text/x-json' }
                         )
    second_page_request = stub_request(:get, 'https://ixc.example.com.br/webservice/v1/cliente')
                          .with(
                            headers: { 'Authorization' => auth_header },
                            body: hash_including('page' => '2', 'rp' => '100')
                          )
                          .to_return(
                            status: 200,
                            body: { registros: second_page_records, total: 101 }.to_json,
                            headers: { 'Content-Type' => 'text/x-json' }
                          )

    result = described_class.new(connection).call_all(mode: 'direct', filters: { active: true })

    expect(result.customers.size).to eq(101)
    expect(first_page_request).to have_been_requested.once
    expect(second_page_request).to have_been_requested.once
  end

  it 'searches contract filters, deduplicates customer ids and fetches clients in batches' do
    contract_request = stub_ixc(
      'cliente_contrato',
      {
        registros: [
          { id: '4914', id_cliente: '4797', id_vd_contrato: '33' },
          { id: '4915', id_cliente: '4797', id_vd_contrato: '33' },
          { id: '4916', id_cliente: '5000', id_vd_contrato: '92' }
        ],
        total: 3
      }
    )
    client_request = stub_ixc(
      'cliente',
      {
        registros: [
          client_record('4797', 'Cliente 4797'),
          client_record('5000', 'Cliente 5000')
        ],
        total: 2
      }
    )

    result = described_class.new(connection).call(
      mode: 'contracts',
      filters: {
        contract_statuses: %w[A P],
        internet_statuses: %w[A CM],
        plan_ids: %w[33 92],
        client_active: true
      },
      limit: 100
    )

    expect(contract_request).to have_been_requested
    expect(client_request).to have_been_requested
    expect(result.customers.map(&:external_id)).to contain_exactly('4797', '5000')
  end

  it 'uses equality for single IXC contract status filters' do
    contract_request = stub_request(:get, 'https://ixc.example.com.br/webservice/v1/cliente_contrato')
                       .with(
                         headers: { 'Authorization' => auth_header },
                         body: hash_including(
                           'qtype' => 'cliente_contrato.status',
                           'query' => 'A',
                           'oper' => '=',
                           'grid_param' => '[{"TB":"cliente_contrato.id_vd_contrato","OP":"IN","P":"33,92"}]'
                         )
                       )
                       .to_return(
                         status: 200,
                         body: {
                           registros: [
                             { id: '4914', id_cliente: '4797', id_vd_contrato: '33' }
                           ],
                           total: 1
                         }.to_json,
                         headers: { 'Content-Type' => 'text/x-json' }
                       )
    client_request = stub_ixc(
      'cliente',
      {
        registros: [client_record('4797', 'Cliente 4797')],
        total: 1
      }
    )

    result = described_class.new(connection).call(
      mode: 'contracts',
      filters: {
        contract_statuses: ['A'],
        plan_ids: %w[33 92]
      },
      limit: 100
    )

    expect(contract_request).to have_been_requested
    expect(client_request).to have_been_requested
    expect(result.customers.map(&:external_id)).to contain_exactly('4797')
  end

  it 'filters contract search customers by customer city and state before pagination' do
    client_grid_param = [
      { 'TB' => 'cliente.ativo', 'OP' => '=', 'P' => 'S' },
      { 'TB' => 'cliente.cidade', 'OP' => '=', 'P' => '1840' },
      { 'TB' => 'cliente.uf', 'OP' => '=', 'P' => '10' }
    ].to_json

    stub_ixc(
      'cliente_contrato',
      {
        registros: [
          { id: '4914', id_cliente: '4797', id_vd_contrato: '33' },
          { id: '4915', id_cliente: '5000', id_vd_contrato: '33' }
        ],
        total: 2
      }
    )
    client_request = stub_request(:get, 'https://ixc.example.com.br/webservice/v1/cliente')
                     .with(
                       headers: { 'Authorization' => auth_header },
                       body: hash_including(
                         'qtype' => 'cliente.id',
                         'query' => '4797,5000',
                         'oper' => 'IN',
                         'grid_param' => client_grid_param
                       )
                     )
                     .to_return(
                       status: 200,
                       body: {
                         registros: [client_record('4797', 'Cliente 4797')],
                         total: 1
                       }.to_json,
                       headers: { 'Content-Type' => 'text/x-json' }
                     )

    result = described_class.new(connection).call(
      mode: 'contracts',
      filters: {
        plan_ids: ['33'],
        client_active: true,
        city_id: '1840',
        state_id: '10'
      },
      limit: 1
    )

    expect(client_request).to have_been_requested
    expect(result.customers.map(&:external_id)).to contain_exactly('4797')
    expect(result.source_total).to eq(2)
  end

  it 'searches active PPPoE records by concentrator before fetching customers' do
    pppoe_request = stub_ixc(
      'radusuarios',
      {
        registros: [
          { id: '1', id_cliente: '4797', id_concentrador: '24', ativo: 'S' },
          { id: '2', id_cliente: '5000', id_concentrador: '24', ativo: 'S' }
        ],
        total: 2
      }
    )
    client_request = stub_ixc(
      'cliente',
      {
        registros: [
          client_record('4797', 'Cliente 4797'),
          client_record('5000', 'Cliente 5000')
        ],
        total: 2
      }
    )

    result = described_class.new(connection).call(
      mode: 'concentrators',
      filters: {
        concentrator_ids: ['24'],
        client_active: true
      },
      limit: 100
    )

    expect(pppoe_request).to have_been_requested
    expect(client_request).to have_been_requested
    expect(result.customers.size).to eq(2)
  end

  it 'searches PPPoE records with POP, transmitter and infrastructure filters' do
    transmitter_request = stub_pop_transmitters
    pppoe_request = stub_advanced_pppoe_search
    client_request = stub_ixc(
      'cliente',
      {
        registros: [client_record('4797', 'Cliente 4797')],
        total: 1
      }
    )

    result = described_class.new(connection).call(
      mode: 'concentrators',
      filters: {
        concentrator_ids: ['24'],
        pop_ids: ['22'],
        transmitter_ids: ['15'],
        transmission_interface_ids: %w[164 117],
        ftth_box_ids: ['9'],
        transmitter_port_ids: %w[31 32],
        client_active: true
      },
      limit: 100
    )

    expect(transmitter_request).to have_been_requested
    expect(pppoe_request).to have_been_requested
    expect(client_request).to have_been_requested
    expect(result.customers.map(&:external_id)).to contain_exactly('4797')
  end

  def stub_pop_transmitters
    stub_request(:get, 'https://ixc.example.com.br/webservice/v1/radpop_radio')
      .with(
        headers: { 'Authorization' => auth_header },
        body: hash_including('qtype' => 'radpop_radio.id_pop', 'query' => '22', 'oper' => '=')
      )
      .to_return(
        status: 200,
        body: {
          registros: [
            { id: '15', descricao: 'OLT_DATACOM_ANDARAI', id_pop: '22' },
            { id: '16', descricao: 'OLT_NOKIA_SEABRA', id_pop: '22' }
          ],
          total: 2
        }.to_json,
        headers: { 'Content-Type' => 'text/x-json' }
      )
  end

  def stub_advanced_pppoe_search
    stub_request(:get, 'https://ixc.example.com.br/webservice/v1/radusuarios')
      .with(
        headers: { 'Authorization' => auth_header },
        body: hash_including(
          'qtype' => 'radusuarios.id_concentrador',
          'query' => '24',
          'oper' => '=',
          'grid_param' => advanced_pppoe_grid_param
        )
      )
      .to_return(
        status: 200,
        body: {
          registros: [{ id: '1', id_cliente: '4797', id_transmissor: '15', ativo: 'S' }],
          total: 1
        }.to_json,
        headers: { 'Content-Type' => 'text/x-json' }
      )
  end

  def advanced_pppoe_grid_param
    [
      { 'TB' => 'radusuarios.id_transmissor', 'OP' => '=', 'P' => '15' },
      { 'TB' => 'radusuarios.interface_transmissao', 'OP' => 'IN', 'P' => '164,117' },
      { 'TB' => 'radusuarios.id_caixa_ftth', 'OP' => '=', 'P' => '9' },
      { 'TB' => 'radusuarios.id_porta_transmissor', 'OP' => 'IN', 'P' => '31,32' },
      { 'TB' => 'radusuarios.ativo', 'OP' => '=', 'P' => 'S' }
    ].to_json
  end

  def stub_ixc(table, response_body)
    stub_request(:get, "https://ixc.example.com.br/webservice/v1/#{table}")
      .with(headers: { 'Authorization' => auth_header })
      .to_return(
        status: 200,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'text/x-json' }
      )
  end

  def stub_lookup_tables
    stub_ixc(
      'cidade',
      {
        registros: [
          { id: '1840', nome: 'Andaraí', uf: '10', cod_ibge: '2901304' }
        ],
        total: 1
      }
    )
    stub_ixc(
      'uf',
      {
        registros: [
          { id: '10', nome: 'Estado da Bahia', sigla: 'BA' }
        ],
        total: 1
      }
    )
  end

  def expect_ixc_brazilian_state_lookup(state_id)
    expect(WebMock).to have_requested(:get, 'https://ixc.example.com.br/webservice/v1/uf')
      .with(
        headers: { 'Authorization' => auth_header },
        body: hash_including(
          'qtype' => 'uf.id',
          'query' => state_id,
          'grid_param' => '[{"TB":"uf.id_pais","OP":"=","P":"2"}]'
        )
      )
  end

  def client_record(id, name)
    {
      id: id,
      razao: name,
      ativo: 'S',
      cidade: '1840',
      uf: '10',
      cep: '46830-000',
      endereco: 'Rua 1',
      bairro: 'Centro',
      whatsapp: '75982479788',
      telefone_celular: '',
      fone: ''
    }
  end
end

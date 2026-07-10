require 'rails_helper'
require 'base64'

RSpec.describe 'Api::V1::Accounts::Ibsoft::MessageBroadcast::Lookups', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:headers) { { api_access_token: admin.access_token.token } }
  let(:auth_header) { "Basic #{Base64.strict_encode64('ixc_user:ixc_password')}" }

  before do
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

  it 'lists IXC states using the Brazilian country id' do
    request = stub_request(:get, 'https://ixc.example.com.br/webservice/v1/uf')
              .with(
                headers: { 'Authorization' => auth_header },
                body: hash_including('qtype' => 'uf.id_pais', 'query' => '2')
              )
              .to_return(
                status: 200,
                body: {
                  registros: [
                    { id: '10', nome: 'Estado da Bahia', sigla: 'BA', id_pais: '2' },
                    { id: '12', nome: 'Distrito Federal', sigla: 'DF', id_pais: '2' },
                    { id: '14', nome: 'Território de Fernando de Noronha', sigla: 'FN', id_pais: '2' }
                  ],
                  total: 3
                }.to_json,
                headers: { 'Content-Type' => 'text/x-json' }
              )

    get "/api/v1/accounts/#{account.id}/ibsoft/message_broadcast/lookups/states",
        headers: headers,
        as: :json

    expect(response).to have_http_status(:success)
    expect(request).to have_been_requested
    expect(response.parsed_body['states']).to contain_exactly(
      include('id' => '10', 'name' => 'Estado da Bahia', 'abbreviation' => 'BA'),
      include('id' => '12', 'name' => 'Distrito Federal', 'abbreviation' => 'DF'),
      include('id' => '14', 'name' => 'Território de Fernando de Noronha', 'abbreviation' => 'FN')
    )
  end

  it 'keeps the Brazilian country filter when searching IXC states' do
    request = stub_request(:get, 'https://ixc.example.com.br/webservice/v1/uf')
              .with(
                headers: { 'Authorization' => auth_header },
                body: hash_including(
                  'qtype' => 'uf.sigla',
                  'query' => 'BA',
                  'grid_param' => '[{"TB":"uf.id_pais","OP":"=","P":"2"}]'
                )
              )
              .to_return(
                status: 200,
                body: {
                  registros: [
                    { id: '10', nome: 'Estado da Bahia', sigla: 'BA', id_pais: '2' }
                  ],
                  total: 1
                }.to_json,
                headers: { 'Content-Type' => 'text/x-json' }
              )

    get "/api/v1/accounts/#{account.id}/ibsoft/message_broadcast/lookups/states",
        params: { query: 'BA' },
        headers: headers,
        as: :json

    expect(response).to have_http_status(:success)
    expect(request).to have_been_requested
    expect(response.parsed_body['states'].first).to include(
      'id' => '10',
      'name' => 'Estado da Bahia',
      'abbreviation' => 'BA'
    )
  end

  it 'lists IXC cities filtered by state' do
    request = stub_request(:get, 'https://ixc.example.com.br/webservice/v1/cidade')
              .with(
                headers: { 'Authorization' => auth_header },
                body: hash_including('qtype' => 'cidade.uf', 'query' => '10')
              )
              .to_return(
                status: 200,
                body: {
                  registros: [{ id: '2193', nome: 'Seabra', uf: '10', cod_ibge: '2929909' }],
                  total: 1
                }.to_json,
                headers: { 'Content-Type' => 'text/x-json' }
              )

    get "/api/v1/accounts/#{account.id}/ibsoft/message_broadcast/lookups/cities",
        params: { state_id: '10' },
        headers: headers,
        as: :json

    expect(response).to have_http_status(:success)
    expect(request).to have_been_requested
    expect(response.parsed_body['cities'].first).to include(
      'id' => '2193',
      'name' => 'Seabra',
      'state_id' => '10'
    )
  end

  it 'lists IXC access plans for selection' do
    request = stub_request(:get, 'https://ixc.example.com.br/webservice/v1/vd_contratos')
              .with(
                headers: { 'Authorization' => auth_header },
                body: hash_including('qtype' => 'vd_contratos.id', 'query' => '1')
              )
              .to_return(
                status: 200,
                body: {
                  registros: [
                    { id: '33', nome: 'Fibra 600 Mega', Ativo: 'S', valor_contrato: '99.90' }
                  ],
                  total: 1
                }.to_json,
                headers: { 'Content-Type' => 'text/x-json' }
              )

    get "/api/v1/accounts/#{account.id}/ibsoft/message_broadcast/lookups/plans",
        headers: headers,
        as: :json

    expect(response).to have_http_status(:success)
    expect(request).to have_been_requested
    expect(response.parsed_body['plans'].first).to include(
      'id' => '33',
      'name' => 'Fibra 600 Mega',
      'active' => true
    )
  end

  it 'lists IXC POPs for selection' do
    request = stub_request(:get, 'https://ixc.example.com.br/webservice/v1/radpop')
              .with(
                headers: { 'Authorization' => auth_header },
                body: hash_including('qtype' => 'radpop.pop', 'query' => 'Centro')
              )
              .to_return(
                status: 200,
                body: {
                  registros: [
                    { id: '22', pop: 'POP Centro', id_cidade: '2193', cep: '46830-000' }
                  ],
                  total: 1
                }.to_json,
                headers: { 'Content-Type' => 'text/x-json' }
              )

    get "/api/v1/accounts/#{account.id}/ibsoft/message_broadcast/lookups/pops",
        params: { query: 'Centro' },
        headers: headers,
        as: :json

    expect(response).to have_http_status(:success)
    expect(request).to have_been_requested
    expect(response.parsed_body['pops'].first).to include(
      'id' => '22',
      'name' => 'POP Centro'
    )
  end

  it 'lists IXC transmitters for selection' do
    request = stub_request(:get, 'https://ixc.example.com.br/webservice/v1/radpop_radio')
              .with(
                headers: { 'Authorization' => auth_header },
                body: hash_including('qtype' => 'radpop_radio.descricao', 'query' => 'DATACOM')
              )
              .to_return(
                status: 200,
                body: {
                  registros: [
                    {
                      id: '15',
                      descricao: 'OLT_DATACOM_ANDARAI',
                      id_pop: '22',
                      ip: '172.31.252.198',
                      ativo: 'S'
                    }
                  ],
                  total: 1
                }.to_json,
                headers: { 'Content-Type' => 'text/x-json' }
              )

    get "/api/v1/accounts/#{account.id}/ibsoft/message_broadcast/lookups/transmitters",
        params: { query: 'DATACOM' },
        headers: headers,
        as: :json

    expect(response).to have_http_status(:success)
    expect(request).to have_been_requested
    expect(response.parsed_body['transmitters'].first).to include(
      'id' => '15',
      'name' => 'OLT_DATACOM_ANDARAI',
      'pop_id' => '22',
      'active' => true
    )
  end
end

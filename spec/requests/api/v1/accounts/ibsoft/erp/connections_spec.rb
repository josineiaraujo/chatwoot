require 'rails_helper'
require 'base64'

RSpec.describe 'Api::V1::Accounts::Ibsoft::Erp::Connections', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:agent_headers) { { api_access_token: agent.access_token.token } }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/erp/connections" }

  it 'lists providers and ERP connections for administrators' do
    create(:ibsoft_erp_connection, account: account, name: 'IXC principal')

    get base_url, headers: admin_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['providers'].pluck('key')).to include('ixc', 'sgp')
    expect(response.parsed_body['connections'].pluck('name')).to include('IXC principal')
    expect(response.parsed_body['connections'].first).not_to include('credentials')
  end

  it 'blocks regular agents from managing ERP connections' do
    get base_url, headers: agent_headers, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'creates an IXC connection with basic authentication' do
    post base_url,
         params: {
           name: 'IXC produção',
           provider: 'ixc',
           auth_type: 'basic',
           base_url: ' https://ixc.example.com.br/ ',
           active: true,
           credentials: {
             username: 'ixc_user',
             password: 'ixc_password'
           }
         },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['name']).to eq('IXC produção')
    expect(response.parsed_body['base_url']).to eq('https://ixc.example.com.br')
    expect(response.parsed_body['active']).to be(true)
    expect(response.parsed_body).not_to include('credentials')
  end

  it 'creates an SGP connection with token and app authentication' do
    post base_url,
         params: {
           name: 'SGP aplicativo',
           provider: 'sgp',
           auth_type: 'token_app',
           base_url: 'https://sgp.example.com.br',
           credentials: {
             token: 'sgp-token',
             app: 'sgp-app'
           }
         },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['provider']).to eq('sgp')
    expect(response.parsed_body['auth_type']).to eq('token_app')
    expect(response.parsed_body['credentials_configured']).to be(true)
  end

  it 'keeps a single active ERP connection per account' do
    first_connection = create(:ibsoft_erp_connection, account: account, active: true)
    second_connection = create(:ibsoft_erp_connection, account: account, active: false)

    patch "#{base_url}/#{second_connection.id}",
          params: { active: true },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(first_connection.reload.active).to be(false)
    expect(second_connection.reload.active).to be(true)
  end

  it 'preserves existing credentials when secret fields are left blank' do
    connection = create(
      :ibsoft_erp_connection,
      account: account,
      credentials: { username: 'old_user', password: 'old_password' }
    )

    patch "#{base_url}/#{connection.id}",
          params: {
            name: 'IXC atualizado',
            credentials: {
              username: '',
              password: 'new_password'
            }
          },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(connection.reload.credentials).to include(
      'username' => 'old_user',
      'password' => 'new_password'
    )
  end

  it 'deletes ERP connections' do
    connection = create(:ibsoft_erp_connection, account: account)

    delete "#{base_url}/#{connection.id}", headers: admin_headers, as: :json

    expect(response).to have_http_status(:no_content)
    expect(Ibsoft::Erp::Connection.exists?(connection.id)).to be(false)
  end

  it 'tests IXC connections by listing one customer record' do
    connection = create(
      :ibsoft_erp_connection,
      account: account,
      provider: 'ixc',
      auth_type: 'basic',
      base_url: 'https://ixc.example.com.br',
      credentials: { username: 'ixc_user', password: 'ixc_password' }
    )

    request = stub_request(
      :get,
      'https://ixc.example.com.br/webservice/v1/cliente'
    )
              .with(
                headers: {
                  'Authorization' => "Basic #{Base64.strict_encode64('ixc_user:ixc_password')}",
                  'Content-Type' => 'application/json',
                  'Ixcsoft' => 'listar'
                },
                body: hash_including('rp' => '1')
              )
              .to_return(
                status: 200,
                body: { registros: [] }.to_json,
                headers: { 'Content-Type' => 'application/json' }
              )

    post "#{base_url}/#{connection.id}/test_connection", headers: admin_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(request).to have_been_requested
    expect(response.parsed_body.dig('test', 'success')).to be(true)
    expect(response.parsed_body.dig('connection', 'last_test_status')).to eq(
      'success'
    )
    expect(connection.reload.last_test_status).to eq('success')
  end

  it 'tests SGP token/app connections by listing one customer record' do
    connection = create(
      :ibsoft_erp_connection,
      account: account,
      provider: 'sgp',
      auth_type: 'token_app',
      base_url: 'https://sgp.example.com.br',
      credentials: { app: 'sgp-app', token: 'sgp-token' }
    )

    request = stub_request(:post, 'https://sgp.example.com.br/api/ura/clientes/')
              .with(
                body: hash_including(
                  'limit' => '1',
                  'app' => 'sgp-app',
                  'token' => 'sgp-token'
                )
              )
              .to_return(
                status: 200,
                body: [].to_json,
                headers: { 'Content-Type' => 'application/json' }
              )

    post "#{base_url}/#{connection.id}/test_connection", headers: admin_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(request).to have_been_requested
    expect(response.parsed_body.dig('test', 'success')).to be(true)
    expect(connection.reload.last_test_status).to eq('success')
  end

  it 'tests SGP basic connections by listing one customer record' do
    connection = create(
      :ibsoft_erp_connection,
      account: account,
      provider: 'sgp',
      auth_type: 'basic',
      base_url: 'https://sgp.example.com.br',
      credentials: { username: 'sgp_user', password: 'sgp_password' }
    )

    request = stub_request(:post, 'https://sgp.example.com.br/api/ura/clientes/')
              .with(
                headers: {
                  'Authorization' => "Basic #{Base64.strict_encode64('sgp_user:sgp_password')}"
                },
                body: hash_including('limit' => '1')
              )
              .to_return(
                status: 200,
                body: [].to_json,
                headers: { 'Content-Type' => 'application/json' }
              )

    post "#{base_url}/#{connection.id}/test_connection",
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)
    expect(request).to have_been_requested
    expect(response.parsed_body.dig('test', 'success')).to be(true)
    expect(connection.reload.last_test_status).to eq('success')
  end

  it 'stores failed status when the ERP rejects the connection test' do
    connection = create(
      :ibsoft_erp_connection,
      account: account,
      provider: 'ixc',
      auth_type: 'basic',
      base_url: 'https://ixc.example.com.br',
      credentials: { username: 'ixc_user', password: 'wrong_password' }
    )

    stub_request(:get, 'https://ixc.example.com.br/webservice/v1/cliente')
      .to_return(status: 401, body: 'unauthorized')

    post "#{base_url}/#{connection.id}/test_connection", headers: admin_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.dig('test', 'success')).to be(false)
    expect(response.parsed_body.dig('test', 'http_status')).to eq(401)
    expect(response.parsed_body.dig('connection', 'last_test_status')).to eq(
      'failed'
    )
    expect(connection.reload.last_test_status).to eq('failed')
  end
end

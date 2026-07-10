require 'rails_helper'
require 'base64'

RSpec.describe 'Api::V1::Accounts::Ibsoft::MessageBroadcast::Recipients', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:agent_headers) { { api_access_token: agent.access_token.token } }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/message_broadcast/recipients/preview" }
  let(:auth_header) { "Basic #{Base64.strict_encode64('ixc_user:ixc_password')}" }

  it 'blocks regular agents from previewing broadcast recipients' do
    post base_url, headers: agent_headers, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'requires an active ERP connection' do
    post base_url,
         params: { mode: 'direct', filters: { name: 'maria' } },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq('active_erp_connection_missing')
  end

  it 'rejects providers without a registered recipient search adapter' do
    create(
      :ibsoft_erp_connection,
      account: account,
      provider: 'sgp',
      auth_type: 'basic',
      active: true
    )

    post base_url,
         params: { mode: 'direct', filters: {} },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq('erp_provider_not_supported')
  end

  it 'returns normalized customers with primary and fallback phones' do
    create_ixc_connection
    stub_ixc('cliente', {
               registros: [client_record('4797', 'Cliente teste', mobile: '75999999999')],
               total: 1
             })
    stub_customer_lookups
    perform_cache_jobs_inline

    post base_url,
         params: { mode: 'direct', filters: { name: 'cliente', active: true }, limit: 10 },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:accepted)

    post base_url,
         params: { mode: 'direct', filters: { name: 'cliente', active: true }, limit: 10 },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)
    customer = response.parsed_body['customers'].first
    expect(customer['name']).to eq('Cliente teste')
    expect(customer.dig('phone_selection', 'primary_phone')).to eq('+5575982479788')
    expect(customer.dig('phone_selection', 'fallback_phone')).to eq('+5575999999999')
    expect(response.parsed_body).to include(
      'page' => 1,
      'per_page' => 10
    )
  end

  it 'paginates the normalized Redis snapshot without repeating the IXC search' do
    create_ixc_connection
    client_request = stub_ixc(
      'cliente',
      {
        registros: [
          client_record('4797', 'Cliente um'),
          client_record('5000', 'Cliente dois')
        ],
        total: 2
      }
    )
    stub_customer_lookups
    perform_cache_jobs_inline

    post base_url,
         params: { mode: 'direct', filters: { active: true }, page: 1, limit: 1 },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:accepted)

    post base_url,
         params: { mode: 'direct', filters: { active: true }, page: 1, limit: 1 },
         headers: admin_headers,
         as: :json
    first_page = response.parsed_body

    post base_url,
         params: { mode: 'direct', filters: { active: true }, page: 2, limit: 1 },
         headers: admin_headers,
         as: :json
    second_page = response.parsed_body

    expect(first_page).to include('total' => 2, 'total_pages' => 2, 'cache_hit' => true)
    expect(second_page).to include('total' => 2, 'total_pages' => 2, 'cache_hit' => true)
    expect(second_page['customers']).to contain_exactly(hash_including('external_id' => '5000'))

    post base_url,
         params: { mode: 'direct', filters: { active: true }, page: 1, limit: 10, query: 'cliente dois' },
         headers: admin_headers,
         as: :json

    expect(response.parsed_body).to include('total' => 1, 'cache_hit' => true)
    expect(response.parsed_body['customers']).to contain_exactly(hash_including('external_id' => '5000'))
    expect(client_request).to have_been_requested.once
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

  def client_record(id, name, mobile: '')
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
      telefone_celular: mobile,
      fone: ''
    }
  end

  def perform_cache_jobs_inline
    allow(Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob).to receive(:perform_later) do |payload|
      Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob.perform_now(payload)
    end
  end

  def create_ixc_connection
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

  def stub_customer_lookups
    stub_ixc('cidade', {
               registros: [{ id: '1840', nome: 'Andaraí', uf: '10', cod_ibge: '2901304' }],
               total: 1
             })
    stub_ixc('uf', {
               registros: [{ id: '10', nome: 'Estado da Bahia', sigla: 'BA' }],
               total: 1
             })
  end
end

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::AccessControl::Roles', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:agent_headers) { { api_access_token: agent.access_token.token } }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/access_control" }

  it 'allows administrators to manage roles' do
    get "#{base_url}/roles", headers: admin_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('roles', 'available_permissions')

    post "#{base_url}/roles",
         params: {
           role: {
             name: 'Supervisor',
             description: 'Acesso de supervisão',
             permissions: %w[conversation_manage ibsoft_conversation_distribution_supervise]
           }
         },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)
    role_id = response.parsed_body['id']

    patch "#{base_url}/roles/#{role_id}",
          params: {
            role: {
              name: 'Supervisor operacional',
              description: 'Acesso operacional',
              permissions: %w[conversation_manage report_manage]
            }
          },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['name']).to eq('Supervisor operacional')

    delete "#{base_url}/roles/#{role_id}", headers: admin_headers, as: :json

    expect(response).to have_http_status(:no_content)
  end

  it 'blocks regular agents from managing roles' do
    get "#{base_url}/roles", headers: agent_headers, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end

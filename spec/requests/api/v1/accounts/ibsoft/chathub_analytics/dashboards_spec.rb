require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::ChathubAnalytics::Dashboards', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:supervisor_user) { create(:user, account: account) }
  let(:agent_headers) { { api_access_token: agent.access_token.token } }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:supervisor_headers) { { api_access_token: supervisor_user.access_token.token } }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/chathub_analytics" }

  def grant_supervisor_permission(user)
    role = create(
      :ibsoft_access_control_role,
      account: account,
      permissions: [Ibsoft::ConversationDistribution::SupervisorPermission::PERMISSION]
    )
    create(:ibsoft_access_control_role_assignment, account: account, role: role, user: user)
  end

  it 'allows agents to read their own dashboard' do
    get "#{base_url}/agent_dashboard", headers: agent_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('summary', 'by_team', 'daily_response')
  end

  it 'blocks regular agents from reading the supervisor dashboard' do
    get "#{base_url}/supervisor_dashboard", headers: agent_headers, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'allows administrators to read the supervisor dashboard' do
    get "#{base_url}/supervisor_dashboard", headers: admin_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('summary', 'top_agents', 'redistribution_ranking')
  end

  it 'allows users with an Ibsoft access profile to read the supervisor dashboard' do
    grant_supervisor_permission(supervisor_user)

    get "#{base_url}/supervisor_dashboard", headers: supervisor_headers, as: :json

    expect(response).to have_http_status(:success)
  end
end

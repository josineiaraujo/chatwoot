require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::AccessControl::RoleAssignments', type: :request do
  let(:account) { create(:account) }
  let!(:admin) { create(:user, :administrator, account: account) }
  let!(:agent) { create(:user, account: account) }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/access_control" }
  let(:role) { create(:ibsoft_access_control_role, account: account) }

  it 'allows administrators to assign and remove profiles' do
    get "#{base_url}/role_assignments", headers: admin_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('assignments', 'roles', 'users', 'available_users')
    expect(response.parsed_body['users'].pluck('id')).to include(admin.id, agent.id)

    post "#{base_url}/role_assignments",
         params: { user_id: agent.id, role_id: role.id },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)
    assignment_id = response.parsed_body['id']
    expect(response.parsed_body.dig('role', 'id')).to eq(role.id)
    expect(response.parsed_body.dig('user', 'id')).to eq(agent.id)

    delete "#{base_url}/role_assignments/#{assignment_id}", headers: admin_headers, as: :json

    expect(response).to have_http_status(:no_content)
  end

  it 'moves an existing assignment when the user already has a profile' do
    other_role = create(:ibsoft_access_control_role, account: account, name: 'Outro perfil')
    create(:ibsoft_access_control_role_assignment, account: account, role: role, user: agent)

    post "#{base_url}/role_assignments",
         params: { user_id: agent.id, role_id: other_role.id },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.dig('role', 'id')).to eq(other_role.id)
    expect(Ibsoft::AccessControl::RoleAssignment.where(account: account, user: agent).count).to eq(1)
  end
end

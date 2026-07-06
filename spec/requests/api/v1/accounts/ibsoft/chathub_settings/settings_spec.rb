require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::ChathubSettings::Settings', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:manager_user) { create(:user, account: account) }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:agent_headers) { { api_access_token: agent.access_token.token } }
  let(:manager_headers) { { api_access_token: manager_user.access_token.token } }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/chathub_settings" }

  def grant_chathub_settings_permission(user)
    role = create(
      :ibsoft_access_control_role,
      account: account,
      permissions: [Ibsoft::ChathubSettings::Permission::PERMISSION]
    )
    create(:ibsoft_access_control_role_assignment, account: account, role: role, user: user)
  end

  describe 'GET /setting' do
    it 'allows administrators to read settings' do
      get "#{base_url}/setting", headers: admin_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('config', 'agent_entry_assignment', 'enabled')).to be(true)
    end

    it 'allows users with an Ibsoft access profile to read settings' do
      grant_chathub_settings_permission(manager_user)

      get "#{base_url}/setting", headers: manager_headers, as: :json

      expect(response).to have_http_status(:success)
    end

    it 'blocks regular agents from reading settings' do
      get "#{base_url}/setting", headers: agent_headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH /setting' do
    it 'allows authorized users to update attendance settings' do
      grant_chathub_settings_permission(manager_user)

      patch "#{base_url}/setting",
            params: {
              config: {
                agent_entry_assignment: {
                  enabled: true,
                  required_percentage: 35,
                  minimum_required: 2,
                  block_close_when_required: false
                },
                login_stabilization: {
                  enabled: true,
                  offline_threshold_minutes: 90,
                  window_minutes: 15,
                  max_assignments_during_window: 2,
                  minimum_online_agents_to_disable: 3
                }
              }
            },
            headers: manager_headers,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('config', 'agent_entry_assignment', 'required_percentage')).to eq(35)
      expect(response.parsed_body.dig('config', 'login_stabilization', 'window_minutes')).to eq(15)
    end

    it 'rejects invalid settings' do
      patch "#{base_url}/setting",
            params: {
              config: {
                agent_entry_assignment: {
                  required_percentage: 130,
                  minimum_required: 0
                }
              }
            },
            headers: admin_headers,
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

end

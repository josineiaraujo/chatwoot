# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::MessageSignature::Settings', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:manager) { create(:user, account: account) }
  let!(:inbox) { create(:inbox, account: account) }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:agent_headers) { { api_access_token: agent.access_token.token } }
  let(:manager_headers) { { api_access_token: manager.access_token.token } }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/message_signature/setting" }

  it 'returns the disabled default configuration to an administrator' do
    get base_url, headers: admin_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq('enabled' => false, 'inbox_ids' => [])
  end

  it 'updates the account configuration' do
    patch base_url,
          params: { enabled: true, inbox_ids: [inbox.id] },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq('enabled' => true, 'inbox_ids' => [inbox.id])
  end

  it 'rejects channels that do not belong to the account' do
    foreign_inbox = create(:inbox)

    patch base_url,
          params: { enabled: true, inbox_ids: [foreign_inbox.id] },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']).to be_present
  end

  it 'blocks regular agents' do
    get base_url, headers: agent_headers, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'allows a user with the ChatHub settings permission' do
    role = create(
      :ibsoft_access_control_role,
      account: account,
      permissions: [Ibsoft::MessageSignature::Permission::PERMISSION]
    )
    create(:ibsoft_access_control_role_assignment, account: account, role: role, user: manager)

    get base_url, headers: manager_headers, as: :json

    expect(response).to have_http_status(:success)
  end
end

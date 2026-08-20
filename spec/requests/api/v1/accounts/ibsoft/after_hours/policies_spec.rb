require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::AfterHours::Policies', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:manager) { create(:user, account: account) }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:agent_headers) { { api_access_token: agent.access_token.token } }
  let(:manager_headers) { { api_access_token: manager.access_token.token } }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/after_hours/policies" }

  def grant_settings_permission(user)
    role = create(
      :ibsoft_access_control_role,
      account: account,
      permissions: [Ibsoft::ChathubSettings::Permission::PERMISSION]
    )
    create(:ibsoft_access_control_role_assignment, account: account, role: role, user: user)
  end

  it 'allows an administrator to create, list and update policies' do
    post base_url,
         params: {
           name: 'Plantao',
           enabled: true,
           exit_command: '  SAIR  ',
           regular_message: 'Estamos fora do horario. Digite sair.',
           holiday_message: 'Hoje e feriado. Digite sair.',
           exit_confirmation_message: 'Atendimento encerrado.'
         },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)
    policy_id = response.parsed_body.fetch('id')
    expect(response.parsed_body).to include(
      'name' => 'Plantao',
      'enabled' => true,
      'exit_command' => 'sair'
    )

    patch "#{base_url}/#{policy_id}",
          params: { name: 'Plantao atualizado', enabled: false },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('name' => 'Plantao atualizado', 'enabled' => false)

    get base_url, headers: admin_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('policies').pluck('id')).to include(policy_id)
  end

  it 'allows a user with the private settings permission to read policies' do
    grant_settings_permission(manager)
    create(:ibsoft_after_hours_policy, account: account, name: 'Politica autorizada')

    get base_url, headers: manager_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('policies').pluck('name')).to include('Politica autorizada')
  end

  it 'blocks a regular agent from managing policies' do
    get base_url, headers: agent_headers, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects enabling a policy without all customer messages' do
    post base_url,
         params: { name: 'Incompleta', enabled: true, exit_command: 'sair' },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.fetch('attributes')).to contain_exactly(
      'regular_message',
      'holiday_message',
      'exit_confirmation_message'
    )
  end

  it 'does not expose a policy from another account' do
    other_account = create(:account)
    foreign_policy = create(:ibsoft_after_hours_policy, account: other_account)

    get "#{base_url}/#{foreign_policy.id}", headers: admin_headers, as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'does not delete a policy while a conversation is actively waiting' do
    policy = create(:ibsoft_after_hours_policy, account: account)
    team = create(:team, account: account)
    conversation = create(:conversation, account: account, team: team)
    create(
      :ibsoft_after_hours_wait,
      account: account,
      after_hours_policy: policy,
      team: team,
      conversation: conversation
    )

    delete "#{base_url}/#{policy.id}", headers: admin_headers, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(policy.reload).to be_present
  end

  it 'resets linked distribution policies to wait when the policy is deleted' do
    policy = create(:ibsoft_after_hours_policy, account: account)
    distribution_policy = create(
      :ibsoft_distribution_policy,
      account: account,
      after_hours_policy: policy,
      config: {
        unavailability: {
          outside_business_hours: { action: 'after_hours_policy' }
        }
      }
    )

    delete "#{base_url}/#{policy.id}", headers: admin_headers, as: :json

    expect(response).to have_http_status(:no_content)
    expect(Ibsoft::AfterHours::Policy.exists?(policy.id)).to be(false)
    expect(distribution_policy.reload.after_hours_policy_id).to be_nil
    expect(distribution_policy.config.dig('unavailability', 'outside_business_hours')).to eq(
      'action' => 'wait',
      'message' => nil,
      'fallback_team_id' => nil
    )
  end
end

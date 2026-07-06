require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::AgentProvisioning::Agents', type: :request do
  let(:account) { create(:account) }
  let!(:admin) { create(:user, :administrator, account: account) }
  let!(:agent) { create(:user, account: account) }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:agent_headers) { { api_access_token: agent.access_token.token } }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/agent_provisioning/agents" }

  it 'lists agents for administrators' do
    profile = create(:ibsoft_access_control_role, account: account, name: 'Supervisor')
    create(:ibsoft_access_control_role_assignment, account: account, role: profile, user: agent)

    get base_url, headers: admin_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['agents'].pluck('id')).to include(admin.id, agent.id)
    expect(response.parsed_body['profiles'].pluck('id')).to include(profile.id)
    expect(response.parsed_body['agents'].find { |item| item['id'] == agent.id }.dig('profile', 'name')).to eq('Supervisor')
  end

  it 'blocks regular agents' do
    get base_url, headers: agent_headers, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'creates a confirmed agent and returns the temporary password once' do
    email = "atendente.teste.#{SecureRandom.hex(4)}@example.com"

    post base_url,
         params: {
           agent: {
             name: 'Atendente Teste',
             email: email,
             role: 'agent'
           }
         },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)

    user = User.from_email(email)
    account_user = account.account_users.find_by!(user: user)

    expect(user).to be_confirmed
    expect(account_user.auto_offline).to be(true)
    expect(user.valid_password?(response.parsed_body['temporary_password'])).to be(true)
    expect(response.parsed_body.dig('agent', 'id')).to eq(user.id)
    expect(response.parsed_body.dig('agent', 'role')).to eq('agent')
  end

  it 'creates a confirmed agent linked to the selected profile' do
    profile = create(:ibsoft_access_control_role, account: account, name: 'Comercial')
    email = "atendente.perfil.#{SecureRandom.hex(4)}@example.com"

    post base_url,
         params: {
           agent: {
             name: 'Atendente Perfil',
             email: email,
             profile_id: profile.id
           }
         },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)

    user = User.from_email(email)
    assignment = Ibsoft::AccessControl::RoleAssignment.find_by!(account: account, user: user)

    expect(response.parsed_body.dig('agent', 'role')).to eq('agent')
    expect(response.parsed_body.dig('agent', 'profile', 'name')).to eq('Comercial')
    expect(assignment.role).to eq(profile)
  end

  it 'creates a confirmed agent with automatic offline disabled when requested' do
    email = "atendente.manual.#{SecureRandom.hex(4)}@example.com"

    post base_url,
         params: {
           agent: {
             name: 'Atendente Manual',
             email: email,
             role: 'agent',
             auto_offline: false
           }
         },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)

    user = User.from_email(email)
    account_user = account.account_users.find_by!(user: user)

    expect(account_user.auto_offline).to be(false)
    expect(response.parsed_body.dig('agent', 'auto_offline')).to be(false)
  end

  it 'creates a confirmed agent with avatar' do
    email = "atendente.avatar.#{SecureRandom.hex(4)}@example.com"
    avatar = fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png')

    post base_url,
         params: {
           agent: {
             name: 'Atendente Avatar',
             email: email,
             role: 'agent',
             avatar: avatar
           }
         },
         headers: admin_headers,
         as: :multipart

    expect(response).to have_http_status(:success)

    user = User.from_email(email)
    expect(user.avatar).to be_attached
    expect(response.parsed_body.dig('agent', 'thumbnail')).to be_present
  end

  it 'updates an agent avatar through the private endpoint' do
    avatar = fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png')

    patch "#{base_url}/#{agent.id}",
          params: {
            agent: {
              name: 'Agente com Avatar',
              role: 'agent',
              avatar: avatar
            }
          },
          headers: admin_headers,
          as: :multipart

    expect(response).to have_http_status(:success)
    expect(agent.reload.name).to eq('Agente com Avatar')
    expect(agent.avatar).to be_attached
    expect(response.parsed_body.dig('agent', 'thumbnail')).to be_present
  end

  it 'updates an agent email through the private endpoint without requiring reconfirmation' do
    new_email = "atendente.editado.#{SecureRandom.hex(4)}@example.com"

    patch "#{base_url}/#{agent.id}",
          params: {
            agent: {
              name: 'Agente com E-mail',
              email: "  #{new_email.upcase}  "
            }
          },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(agent.reload.name).to eq('Agente com E-mail')
    expect(agent.email).to eq(new_email)
    expect(agent.uid).to eq(new_email)
    expect(agent.unconfirmed_email).to be_blank
    expect(agent).to be_confirmed
    expect(response.parsed_body.dig('agent', 'email')).to eq(new_email)
  end

  it 'normalizes manual availability when automatic offline is active' do
    account_user = account.account_users.find_by!(user: agent)
    account_user.update!(availability: :offline, auto_offline: true)

    patch "#{base_url}/#{agent.id}",
          params: {
            agent: {
              availability: 'busy'
            }
          },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(account_user.reload.availability).to eq('offline')
    expect(account_user.auto_offline).to be(true)
    expect(response.parsed_body.dig('agent', 'availability')).to eq('offline')
    expect(response.parsed_body.dig('agent', 'availability_status')).to eq('offline')
  end

  it 'keeps manual availability when automatic offline is disabled' do
    account_user = account.account_users.find_by!(user: agent)
    account_user.update!(availability: :offline, auto_offline: false)

    patch "#{base_url}/#{agent.id}",
          params: {
            agent: {
              availability: 'busy'
            }
          },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(account_user.reload.availability).to eq('busy')
    expect(response.parsed_body.dig('agent', 'availability')).to eq('busy')
    expect(response.parsed_body.dig('agent', 'availability_status')).to eq('busy')
  end

  it 'updates an agent automatic offline option through the private endpoint' do
    account_user = account.account_users.find_by!(user: agent)
    account_user.update!(auto_offline: true)

    patch "#{base_url}/#{agent.id}",
          params: {
            agent: {
              auto_offline: false
            }
          },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(account_user.reload.auto_offline).to be(false)
    expect(response.parsed_body.dig('agent', 'auto_offline')).to be(false)
  end

  it 'generates a new temporary password for an account agent' do
    previous_encrypted_password = agent.encrypted_password

    post "#{base_url}/#{agent.id}/reset_temporary_password",
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)

    temporary_password = response.parsed_body['temporary_password']

    expect(temporary_password).to be_present
    expect(response.parsed_body.dig('agent', 'id')).to eq(agent.id)
    expect(agent.reload.encrypted_password).not_to eq(previous_encrypted_password)
    expect(agent.valid_password?(temporary_password)).to be(true)
  end

  it 'returns validation errors without creating a user' do
    expect do
      post base_url,
           params: {
             agent: {
               name: 'Duplicado',
               email: admin.email,
               role: 'agent'
             }
           },
           headers: admin_headers,
           as: :json
    end.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']).to eq(I18n.t('ibsoft.agent_provisioning.errors.email_taken'))
    expect(response.parsed_body).not_to include('temporary_password')
  end
end

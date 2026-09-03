require 'rails_helper'

RSpec.describe 'Ibsoft access-control permissions in profile payload', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  it 'returns private permissions only for the account where they were assigned' do
    other_account = create(:account)
    create(:account_user, account: other_account, user: agent, role: :agent)
    private_role = create(
      :ibsoft_access_control_role,
      account: account,
      permissions: ['ibsoft_message_broadcast_manage']
    )
    create(
      :ibsoft_access_control_role_assignment,
      account: account,
      role: private_role,
      user: agent
    )

    get '/api/v1/profile',
        headers: agent.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    accounts = response.parsed_body.fetch('accounts').index_by { |item| item.fetch('id') }
    expect(accounts.fetch(account.id).fetch('permissions')).to include('ibsoft_message_broadcast_manage')
    expect(accounts.fetch(other_account.id).fetch('permissions')).not_to include('ibsoft_message_broadcast_manage')
  end
end

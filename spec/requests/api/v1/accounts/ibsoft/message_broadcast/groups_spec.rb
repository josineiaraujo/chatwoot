require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::MessageBroadcast::Groups', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:agent_headers) { { api_access_token: agent.access_token.token } }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/message_broadcast/groups" }

  let!(:active_connection) { create(:ibsoft_erp_connection, account: account, provider: 'ixc', active: true) }

  it 'blocks regular agents' do
    get base_url, headers: agent_headers, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'creates fixed groups with selected members' do
    post base_url,
         params: {
           name: 'Clientes Seabra',
           description: 'Grupo de teste',
           members: [
             {
               external_customer_id: '4797',
               customer_name: 'Cliente teste',
               primary_phone: '+5575982479788',
               fallback_phone: '+5575999999999',
               city: 'Seabra',
               state: 'BA',
               active: true
             }
           ]
         },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['name']).to eq('Clientes Seabra')
    expect(response.parsed_body['erp_provider']).to eq('ixc')
    expect(response.parsed_body['members'].first).to include(
      'external_customer_id' => '4797',
      'primary_phone' => '+5575982479788'
    )
  end

  it 'updates group members by replacing the fixed list' do
    group = create(:ibsoft_message_broadcast_group, account: account, created_by: admin)
    create(:ibsoft_message_broadcast_group_member, group: group, external_customer_id: 'old')

    patch "#{base_url}/#{group.id}",
          params: {
            name: 'Clientes atualizados',
            members: [
              {
                external_customer_id: 'new',
                customer_name: 'Novo cliente',
                primary_phone: '+5575982479788'
              }
            ]
          },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(group.reload.members.pluck(:external_customer_id)).to eq(['new'])
  end

  it 'rolls back the group update when a replacement member is invalid' do
    group = create(:ibsoft_message_broadcast_group, account: account, created_by: admin, name: 'Original')
    create(:ibsoft_message_broadcast_group_member, group: group, external_customer_id: 'kept')

    patch "#{base_url}/#{group.id}",
          params: {
            name: 'Alterado',
            members: [{ external_customer_id: 'invalid' }]
          },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(group.reload.name).to eq('Original')
    expect(group.members.pluck(:external_customer_id)).to eq(['kept'])
  end

  it 'creates a group from every customer in an account-scoped cached search' do
    cache = Ibsoft::MessageBroadcast::RecipientSearchCache.new(account: account, connection: active_connection)
    token = cache.token_for('direct', active: true)
    cache.write(
      token,
      customers: [
        {
          external_id: '4797',
          name: 'Cliente teste',
          active: true,
          city_name: 'Seabra',
          state: 'BA',
          phone_selection: {
            primary_phone: '+5575982479788',
            fallback_phone: '+5575999999999'
          }
        }
      ]
    )

    post base_url,
         params: {
           name: 'Todos do filtro',
           selection: { scope: 'all', search_token: token }
         },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['members'].sole).to include(
      'external_customer_id' => '4797',
      'customer_name' => 'Cliente teste',
      'city' => 'Seabra'
    )
  end

  it 'does not persist an empty group when the cached selection expired' do
    expect do
      post base_url,
           params: {
             name: 'Snapshot expirado',
             selection: { scope: 'all', search_token: 'expired' }
           },
           headers: admin_headers,
           as: :json
    end.not_to change(Ibsoft::MessageBroadcast::Group, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']).to eq('recipient_selection_expired')
  end
end

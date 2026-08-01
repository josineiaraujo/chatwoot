require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::ExternalMessaging::Deliveries', type: :request do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:headers) { { api_access_token: admin.access_token.token } }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/external_messaging/deliveries" }

  it 'returns only deliveries belonging to the current account' do
    current_delivery = create(
      :ibsoft_external_message_delivery,
      endpoint: create(:ibsoft_external_message_endpoint, account: account)
    )
    create(
      :ibsoft_external_message_delivery,
      endpoint: create(:ibsoft_external_message_endpoint, account: other_account)
    )

    get base_url, headers: headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['deliveries'].pluck('id')).to eq([current_delivery.id])
    expect(response.parsed_body['meta']).to include('page' => 1, 'per_page' => 25, 'total' => 1)
  end

  it 'filters by status and endpoint' do
    endpoint = create(:ibsoft_external_message_endpoint, account: account)
    accepted = create(
      :ibsoft_external_message_delivery,
      endpoint: endpoint,
      status: 'accepted',
      meta_message_id: 'wamid.accepted'
    )
    create(:ibsoft_external_message_delivery, endpoint: endpoint, status: 'failed')

    get base_url,
        params: { endpoint_id: endpoint.id, status: 'accepted' },
        headers: headers,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['deliveries'].pluck('id')).to eq([accepted.id])
  end
end

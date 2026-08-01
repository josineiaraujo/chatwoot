require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::ExternalMessaging::Orders', type: :request do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:headers) { { api_access_token: admin.access_token.token } }
  let(:endpoint) { create(:ibsoft_external_message_endpoint, account: account) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/external_messaging/orders" }

  def create_order(reference:, recipient:, created_at: Time.current)
    delivery = create(
      :ibsoft_external_message_delivery,
      endpoint: endpoint,
      template_type: 'order',
      order_reference_id: reference,
      recipient: recipient,
      status: 'accepted',
      meta_message_id: "wamid.#{reference}",
      created_at: created_at
    )
    create(
      :ibsoft_external_message_order,
      opening_delivery: delivery,
      reference_id: reference,
      created_at: created_at
    )
  end

  it 'lists paginated orders filtered by recipient and date' do
    matching = create_order(
      reference: 'invoice-match',
      recipient: '5575982479788',
      created_at: Time.zone.parse('2026-07-10 10:00:00')
    )
    create_order(
      reference: 'invoice-other',
      recipient: '5575999999999',
      created_at: Time.zone.parse('2026-07-10 10:00:00')
    )

    get base_url,
        params: {
          endpoint_id: endpoint.id,
          recipient: '98247',
          date_from: '2026-07-01',
          date_to: '2026-07-31'
        },
        headers: headers,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['orders'].pluck('id')).to eq([matching.id])
    expect(response.parsed_body['orders'].first).to include(
      'reference_id' => 'invoice-match',
      'manually_updateable' => true
    )
    expect(response.parsed_body['meta']).to include('page' => 1, 'per_page' => 25, 'total' => 1)
  end

  it 'queues a manual update for all orders matching the filter' do
    create_order(reference: 'invoice-1', recipient: '5575982479788')

    expect do
      post "#{base_url}/bulk_update",
           params: {
             endpoint_id: endpoint.id,
             selection: { mode: 'filter' },
             filters: { recipient: '98247' },
             update: { payment_status: 'captured' }
           },
           headers: headers,
           as: :json
    end.to have_enqueued_job(Ibsoft::ExternalMessaging::BulkOrderUpdateJob)

    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body).to include('accepted' => true, 'count' => 1)
  end

  it 'does not expose orders from another account' do
    foreign_endpoint = create(:ibsoft_external_message_endpoint)

    get base_url,
        params: { endpoint_id: foreign_endpoint.id },
        headers: headers,
        as: :json

    expect(response).to have_http_status(:not_found)
  end
end

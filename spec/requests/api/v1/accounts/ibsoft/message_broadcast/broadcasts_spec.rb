require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::MessageBroadcast::Broadcasts', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/message_broadcast/broadcasts" }
  let(:inbox) { create(:inbox, account: account) }
  let(:broadcast_params) do
    {
      inbox_id: inbox.id,
      source_type: 'selection',
      template_name: 'aviso_manutencao',
      template_language: 'pt_BR',
      conversation_mode: 'close_after_send',
      template_variables: {
        '1' => { type: 'fixed', value: "Hoje\nà tarde" }
      },
      recipients: [
        {
          external_customer_id: '4797',
          customer_name: 'Cliente teste',
          primary_phone: '+5575982479788',
          fallback_phone: '+5575999999999',
          template_variable_values: {
            '1' => "Cliente\nteste"
          }
        },
        {
          external_customer_id: '5000',
          customer_name: 'Cliente sem telefone'
        }
      ]
    }
  end

  before do
    create(:ibsoft_erp_connection, account: account, provider: 'ixc', active: true)
  end

  it 'creates draft broadcasts without sending messages' do
    expect do
      post base_url,
           params: broadcast_params,
           headers: admin_headers,
           as: :json
    end.not_to change(Message, :count)

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['status']).to eq('draft')
    expect(Ibsoft::MessageBroadcast::Broadcast.last.template_variables).to include(
      '1' => include('type' => 'fixed', 'value' => 'Hoje à tarde')
    )
    expect(Ibsoft::MessageBroadcast::Broadcast.last.recipients.find_by(external_customer_id: '4797').template_variable_values).to include(
      '1' => 'Cliente teste'
    )
    expect(response.parsed_body['recipients'].size).to eq(2)
    skipped_recipient = response.parsed_body['recipients'].find { |recipient| recipient['status'] == 'skipped' }

    expect(skipped_recipient).to include(
      'status' => 'skipped',
      'error_code' => 'without_valid_phone'
    )
  end

  it 'does not enqueue a saved draft' do
    allow(Ibsoft::MessageBroadcast::SendBroadcastJob).to receive(:perform_later)

    post base_url, params: broadcast_params, headers: admin_headers, as: :json

    expect(Ibsoft::MessageBroadcast::SendBroadcastJob).not_to have_received(:perform_later)
  end

  it 'creates and queues an immediate broadcast without requiring a draft action' do
    allow(Ibsoft::MessageBroadcast::SendBroadcastJob).to receive(:perform_later)

    post base_url,
         params: broadcast_params.merge(send_now: true),
         headers: admin_headers,
         as: :json

    broadcast = Ibsoft::MessageBroadcast::Broadcast.last
    expect(response).to have_http_status(:success)
    expect(response.parsed_body['status']).to eq('queued')
    expect(broadcast).to have_attributes(status: 'queued', sent_by: admin)
    expect(broadcast.recipients.pluck(:status)).to contain_exactly('queued', 'skipped')
    expect(Ibsoft::MessageBroadcast::SendBroadcastJob).to have_received(:perform_later).with(broadcast.id)
  end

  it 'does not create an immediate broadcast without a deliverable recipient' do
    invalid_params = broadcast_params.merge(
      send_now: true,
      recipients: [{ external_customer_id: '5000', customer_name: 'Cliente sem telefone' }]
    )

    expect do
      post base_url, params: invalid_params, headers: admin_headers, as: :json
    end.not_to change(Ibsoft::MessageBroadcast::Broadcast, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq('broadcast_without_pending_recipients')
  end

  it 'queues a draft broadcast for sending' do
    broadcast = create(:ibsoft_message_broadcast, account: account, inbox: inbox, created_by: admin)
    create(:ibsoft_message_broadcast_recipient, broadcast: broadcast)

    allow(Ibsoft::MessageBroadcast::SendBroadcastJob).to receive(:perform_later)

    post "#{base_url}/#{broadcast.id}/send_broadcast", headers: admin_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['status']).to eq('queued')
    expect(broadcast.reload.status).to eq('queued')
    expect(broadcast.sent_by).to eq(admin)
    expect(broadcast.recipients.pluck(:status)).to contain_exactly('queued')
    expect(Ibsoft::MessageBroadcast::SendBroadcastJob).to have_received(:perform_later).with(broadcast.id)
  end
end

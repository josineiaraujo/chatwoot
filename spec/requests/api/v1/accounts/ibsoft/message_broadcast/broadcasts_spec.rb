require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::MessageBroadcast::Broadcasts', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/message_broadcast/broadcasts" }
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:inbox) { channel.inbox }
  let(:broadcast_params) do
    {
      inbox_id: inbox.id,
      source_type: 'selection',
      dispatch_mode: 'bulk',
      template_name: 'aviso_manutencao',
      template_language: 'pt_BR',
      conversation_mode: 'direct',
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

  it 'returns the broadcast history with database pagination and newest records first', :aggregate_failures do
    erp_connection = Ibsoft::Erp::Connection.find_by!(account: account, active: true)
    oldest = create(
      :ibsoft_message_broadcast,
      account: account,
      inbox: inbox,
      erp_connection: erp_connection,
      created_by: admin,
      created_at: 3.days.ago
    )
    middle = create(
      :ibsoft_message_broadcast,
      account: account,
      inbox: inbox,
      erp_connection: erp_connection,
      created_by: admin,
      created_at: 2.days.ago
    )
    newest = create(
      :ibsoft_message_broadcast,
      account: account,
      inbox: inbox,
      erp_connection: erp_connection,
      created_by: admin,
      created_at: 1.day.ago
    )
    create_list(:ibsoft_message_broadcast_recipient, 2, broadcast: oldest)
    create(:ibsoft_message_broadcast_recipient, broadcast: newest)

    get base_url, params: { page: 1, per_page: 2 }, headers: admin_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['broadcasts'].pluck('id')).to eq([newest.id, middle.id])
    expect(response.parsed_body['broadcasts'].first['recipients_count']).to eq(1)
    expect(response.parsed_body['broadcasts'].first['deletable']).to be(true)
    expect(response.parsed_body['broadcasts'].first['created_by']).to eq(
      'id' => admin.id,
      'name' => admin.name
    )
    expect(response.parsed_body['meta']).to eq(
      'page' => 1,
      'per_page' => 2,
      'total' => 3,
      'total_pages' => 2
    )

    get base_url, params: { page: 2, per_page: 2 }, headers: admin_headers, as: :json

    expect(response.parsed_body['broadcasts'].pluck('id')).to eq([oldest.id])
    expect(response.parsed_body['broadcasts'].first['recipients_count']).to eq(2)
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

  it 'sends an individual broadcast inline with exactly one recipient', :aggregate_failures do
    allow(Ibsoft::MessageBroadcast::BroadcastSender).to receive(:new).and_call_original
    recipient_sender = instance_double(Ibsoft::MessageBroadcast::RecipientSender)
    allow(Ibsoft::MessageBroadcast::RecipientSender).to receive(:new).and_return(recipient_sender)
    allow(recipient_sender).to receive(:call) do
      Ibsoft::MessageBroadcast::Recipient.last.update!(status: 'accepted', meta_message_id: 'wamid.single')
    end

    post base_url,
         params: broadcast_params.merge(
           dispatch_mode: 'single',
           send_now: true,
           recipients: [broadcast_params[:recipients].first]
         ),
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('dispatch_mode' => 'single', 'status' => 'completed')
    expect(Ibsoft::MessageBroadcast::SendBroadcastJob).not_to have_been_enqueued
  end

  it 'rejects an individual broadcast with more than one recipient' do
    post base_url,
         params: broadcast_params.merge(dispatch_mode: 'single'),
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']).to eq('invalid_broadcast_dispatch')
  end

  it 'rejects a non-cloud WhatsApp inbox' do
    unsupported_inbox = create(:inbox, account: account)

    post base_url,
         params: broadcast_params.merge(inbox_id: unsupported_inbox.id),
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']).to eq('invalid_whatsapp_cloud_inbox')
  end

  it 'does not create an immediate broadcast without a deliverable recipient' do
    invalid_params = broadcast_params.merge(
      send_now: true,
      recipients: [{ external_customer_id: '5000', customer_name: 'Cliente sem telefone' }]
    )

    expect do
      post base_url, params: invalid_params, headers: admin_headers, as: :json
    end.not_to change(Ibsoft::MessageBroadcast::Broadcast, :count)

    expect(response).to have_http_status(:unprocessable_content)
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

  it 'does not enqueue the same draft twice', :aggregate_failures do
    broadcast = create(:ibsoft_message_broadcast, account: account, inbox: inbox, created_by: admin)
    create(:ibsoft_message_broadcast_recipient, broadcast: broadcast)
    allow(Ibsoft::MessageBroadcast::SendBroadcastJob).to receive(:perform_later)

    post "#{base_url}/#{broadcast.id}/send_broadcast", headers: admin_headers, as: :json
    post "#{base_url}/#{broadcast.id}/send_broadcast", headers: admin_headers, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']).to eq('broadcast_not_draft')
    expect(Ibsoft::MessageBroadcast::SendBroadcastJob).to have_received(:perform_later).once
  end

  it 'deletes a completed broadcast and its private recipient records' do
    broadcast = create(
      :ibsoft_message_broadcast,
      account: account,
      inbox: inbox,
      created_by: admin,
      status: 'completed'
    )
    recipient = create(:ibsoft_message_broadcast_recipient, broadcast: broadcast)

    delete "#{base_url}/#{broadcast.id}", headers: admin_headers, as: :json

    expect(response).to have_http_status(:no_content)
    expect(Ibsoft::MessageBroadcast::Broadcast.exists?(broadcast.id)).to be(false)
    expect(Ibsoft::MessageBroadcast::Recipient.exists?(recipient.id)).to be(false)
  end

  it 'does not delete a queued or running broadcast' do
    broadcast = create(
      :ibsoft_message_broadcast,
      account: account,
      inbox: inbox,
      created_by: admin,
      status: 'running'
    )

    delete "#{base_url}/#{broadcast.id}", headers: admin_headers, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq(
      'error' => 'broadcast_in_progress',
      'blocked_ids' => [broadcast.id]
    )
    expect(Ibsoft::MessageBroadcast::Broadcast.exists?(broadcast.id)).to be(true)
  end

  it 'deletes a valid selection in one operation' do
    broadcasts = %w[draft failed cancelled].map do |status|
      create(
        :ibsoft_message_broadcast,
        account: account,
        inbox: inbox,
        created_by: admin,
        status: status
      )
    end

    delete "#{base_url}/bulk_destroy",
           params: { ids: broadcasts.map(&:id) },
           headers: admin_headers,
           as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['deleted_ids']).to match_array(broadcasts.map(&:id))
    expect(Ibsoft::MessageBroadcast::Broadcast.where(id: broadcasts.map(&:id)).count).to eq(0)
  end

  it 'keeps the entire selection when one broadcast is still active' do
    completed = create(
      :ibsoft_message_broadcast,
      account: account,
      inbox: inbox,
      created_by: admin,
      status: 'completed'
    )
    queued = create(
      :ibsoft_message_broadcast,
      account: account,
      inbox: inbox,
      created_by: admin,
      status: 'queued'
    )

    delete "#{base_url}/bulk_destroy",
           params: { ids: [completed.id, queued.id] },
           headers: admin_headers,
           as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']).to eq('broadcast_in_progress')
    expect(Ibsoft::MessageBroadcast::Broadcast.where(id: [completed.id, queued.id]).count).to eq(2)
  end

  it 'does not partially delete a selection containing another account record' do
    own_broadcast = create(
      :ibsoft_message_broadcast,
      account: account,
      inbox: inbox,
      created_by: admin,
      status: 'completed'
    )
    other_broadcast = create(:ibsoft_message_broadcast, status: 'completed')

    delete "#{base_url}/bulk_destroy",
           params: { ids: [own_broadcast.id, other_broadcast.id] },
           headers: admin_headers,
           as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']).to eq('invalid_broadcast_selection')
    expect(Ibsoft::MessageBroadcast::Broadcast.exists?(own_broadcast.id)).to be(true)
    expect(Ibsoft::MessageBroadcast::Broadcast.exists?(other_broadcast.id)).to be(true)
  end
end

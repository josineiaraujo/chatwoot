require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrderUpdateSender do
  let(:update) { create(:ibsoft_external_message_order_update) }
  let(:messages_url) do
    phone_number_id = update.inbox.channel.provider_config['phone_number_id']
    "https://graph.facebook.com/v22.0/#{phone_number_id}/messages"
  end

  before do
    allow(GlobalConfigService).to receive(:load)
      .with('WHATSAPP_API_VERSION', 'v22.0')
      .and_return('v22.0')
    allow(Redis::Alfred).to receive(:set).and_return('OK')
  end

  it 'sends an interactive order status directly to Meta and updates canonical state' do
    request = stub_request(:post, messages_url).with do |meta_request|
      body = JSON.parse(meta_request.body)
      body['to'] == update.order.opening_delivery.recipient &&
        body.dig('interactive', 'type') == 'order_status' &&
        body.dig('interactive', 'action', 'parameters', 'reference_id') == update.order.reference_id &&
        body.dig('interactive', 'action', 'parameters', 'order', 'status') == 'processing'
    end.to_return(
      status: 200,
      body: { messages: [{ id: 'wamid.order-update-1' }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    expect do
      described_class.new(update: update).call
    end.to not_change(Conversation, :count).and not_change(Message, :count)

    expect(request).to have_been_requested.once
    expect(update.reload).to have_attributes(
      status: 'accepted',
      meta_message_id: 'wamid.order-update-1',
      attempts_count: 1
    )
    expect(update.order.reload.order_status).to eq('processing')
  end

  it 'sends the snapshotted template directly to Meta without creating Chatwoot records' do
    update.update!(
      delivery_method: 'template',
      template_name: 'atualizacao_fatura',
      template_language: 'pt_BR',
      template_components: [
        {
          type: 'body',
          parameters: [
            {
              type: 'text',
              text: 'Sua fatura está em processamento.',
              parameter_name: 'mensagem_status'
            }
          ]
        }
      ]
    )
    request = stub_request(:post, messages_url).with do |meta_request|
      body = JSON.parse(meta_request.body)
      body['to'] == update.order.recipient &&
        body['type'] == 'template' &&
        body.dig('template', 'name') == 'atualizacao_fatura' &&
        body.dig('template', 'language', 'code') == 'pt_BR' &&
        body.dig('template', 'components', 0, 'parameters', 0, 'parameter_name') == 'mensagem_status' &&
        body.dig('template', 'components', 0, 'parameters', 0, 'text') ==
          'Sua fatura está em processamento.' &&
        body.dig('template', 'components', 1, 'type') == 'order_status' &&
        body.dig('template', 'components', 1, 'parameters', 0, 'order_status', 'reference_id') ==
          update.order.reference_id &&
        body.dig('template', 'components', 1, 'parameters', 0, 'order_status', 'order', 'status') ==
          'processing'
    end.to_return(
      status: 200,
      body: { messages: [{ id: 'wamid.template-update-1' }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    expect do
      described_class.new(update: update).call
    end.to not_change(Conversation, :count).and not_change(Message, :count)

    expect(request).to have_been_requested.once
    expect(update.reload).to have_attributes(
      status: 'accepted',
      meta_message_id: 'wamid.template-update-1'
    )
  end

  it 'sends the original order reference when the selected template has no variables' do
    update.update!(
      delivery_method: 'template',
      template_name: 'atualizacao_sem_variavel',
      template_language: 'pt_BR',
      template_components: []
    )
    request = stub_request(:post, messages_url).with do |meta_request|
      body = JSON.parse(meta_request.body)
      body['type'] == 'template' &&
        body.dig('template', 'name') == 'atualizacao_sem_variavel' &&
        body.dig('template', 'components', 0, 'type') == 'order_status' &&
        body.dig('template', 'components', 0, 'parameters', 0, 'order_status', 'reference_id') ==
          update.order.reference_id
    end.to_return(
      status: 200,
      body: { messages: [{ id: 'wamid.template-without-variable' }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    described_class.new(update: update).call

    expect(request).to have_been_requested.once
    expect(update.reload.status).to eq('accepted')
  end

  it 'updates order and payment together after Meta accepts a paid template' do
    update.update!(
      order_status: 'completed',
      payment_status: 'captured',
      delivery_method: 'template',
      template_name: 'pagamento_confirmado',
      template_language: 'pt_BR',
      template_components: []
    )
    request = stub_request(:post, messages_url).with do |meta_request|
      body = JSON.parse(meta_request.body)
      body.dig('template', 'components', 0, 'parameters', 0, 'order_status') == {
        'reference_id' => update.order.reference_id,
        'order' => {
          'status' => 'completed',
          'description' => update.description
        }
      }
    end.to_return(
      status: 200,
      body: { messages: [{ id: 'wamid.paid-order-update' }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    expect do
      described_class.new(update: update).call
    end.to not_change(Conversation, :count).and not_change(Message, :count)

    expect(request).to have_been_requested.once
    expect(update.order.reload).to have_attributes(
      order_status: 'completed',
      payment_status: 'captured'
    )
  end

  it 'does not fall back to an interactive update when Meta rejects the template' do
    update.update!(
      delivery_method: 'template',
      template_name: 'atualizacao_fatura',
      template_language: 'pt_BR',
      template_components: []
    )
    request = stub_request(:post, messages_url).with do |meta_request|
      JSON.parse(meta_request.body)['type'] == 'template'
    end.to_return(
      status: 400,
      body: { error: { code: 13_200, message: 'Template rejected' } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    described_class.new(update: update).call

    expect(request).to have_been_requested.once
    expect(update.reload).to have_attributes(
      status: 'failed',
      error_code: '13200',
      attempts_count: 1
    )
  end

  it 'allows only one worker to claim the update' do
    request = stub_request(:post, messages_url).to_return(
      status: 200,
      body: { messages: [{ id: 'wamid.order-update-1' }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    2.times { described_class.new(update: update).call }

    expect(request).to have_been_requested.once
  end

  it 'keeps updates for the same order in creation order' do
    later = create(
      :ibsoft_external_message_order_update,
      order: update.order,
      order_status: 'completed',
      message_content: 'Completed'
    )
    request = stub_request(:post, messages_url).to_return(
      {
        status: 200,
        body: { messages: [{ id: 'wamid.order-update-1' }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      },
      {
        status: 200,
        body: { messages: [{ id: 'wamid.order-update-2' }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      }
    )

    described_class.new(update: later).call
    expect(later.reload.status).to eq('queued')
    expect(request).not_to have_been_requested

    expect do
      described_class.new(update: update).call
    end.to have_enqueued_job(Ibsoft::ExternalMessaging::SendOrderUpdateJob).with(later.id)

    described_class.new(update: later).call
    expect(request).to have_been_requested.twice
    expect(update.order.reload.order_status).to eq('completed')
  end

  it 'marks a definitive Meta rejection as failed and allows the next update' do
    later = create(
      :ibsoft_external_message_order_update,
      order: update.order,
      order_status: 'completed'
    )
    stub_request(:post, messages_url).to_return(
      status: 400,
      body: { error: { code: 13_200, message: 'Rejected' } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    expect do
      described_class.new(update: update).call
    end.to have_enqueued_job(Ibsoft::ExternalMessaging::SendOrderUpdateJob).with(later.id)

    expect(update.reload).to have_attributes(status: 'failed', error_code: '13200')
  end

  it 'marks a timeout as uncertain and blocks later updates' do
    later = create(
      :ibsoft_external_message_order_update,
      order: update.order,
      order_status: 'completed'
    )
    stub_request(:post, messages_url).to_timeout

    expect do
      described_class.new(update: update).call
    end.not_to have_enqueued_job(Ibsoft::ExternalMessaging::SendOrderUpdateJob).with(later.id)

    expect(update.reload.status).to eq('uncertain')
    expect(later.reload.status).to eq('queued')
  end

  it 'reschedules rate-limited work without calling Meta' do
    allow(Redis::Alfred).to receive(:set).and_return(nil)
    allow(Redis::Alfred).to receive(:incr).and_return(11)

    expect do
      described_class.new(update: update).call
    end.to have_enqueued_job(Ibsoft::ExternalMessaging::SendOrderUpdateJob).with(update.id)

    expect(update.reload).to have_attributes(status: 'queued', attempts_count: 0)
    expect(a_request(:post, messages_url)).not_to have_been_made
  end
end

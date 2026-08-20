require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::DeliverySender do
  let(:template_components) do
    [
      {
        'type' => 'body',
        'parameters' => [{ 'type' => 'text', 'text' => 'Maria' }]
      }
    ]
  end
  let(:delivery) do
    create(
      :ibsoft_external_message_delivery,
      template_components: template_components
    )
  end
  let(:messages_url) do
    "https://graph.facebook.com/v22.0/#{delivery.inbox.channel.provider_config['phone_number_id']}/messages"
  end

  before do
    allow(GlobalConfigService).to receive(:load)
      .with('WHATSAPP_API_VERSION', 'v22.0')
      .and_return('v22.0')
    allow(Redis::Alfred).to receive(:set).and_return('OK')
  end

  it 'sends directly to Meta without creating Chatwoot conversations or messages', :aggregate_failures do
    request = stub_request(:post, messages_url).with do |meta_request|
      JSON.parse(meta_request.body).dig('template', 'components') == template_components
    end.to_return(
      status: 200,
      body: { messages: [{ id: 'wamid.external-1' }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    expect do
      described_class.new(delivery: delivery).call
    end.to not_change(Conversation, :count).and not_change(Message, :count)

    expect(request).to have_been_requested.once
    expect(delivery.reload).to have_attributes(
      status: 'accepted',
      meta_message_id: 'wamid.external-1',
      attempts_count: 1,
      template_components: []
    )
  end

  it 'allows only one worker to claim and send a delivery' do
    request = stub_request(:post, messages_url).to_return(
      status: 200,
      body: { messages: [{ id: 'wamid.external-1' }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    2.times { described_class.new(delivery: delivery).call }

    expect(request).to have_been_requested.once
  end

  it 'marks a definitive Meta rejection as failed' do
    delivery.endpoint.update!(failure_diagnostics_enabled: true)
    stub_request(:post, messages_url).to_return(
      status: 400,
      body: {
        error: {
          code: 132_000,
          message: '(#132000) Number of parameters does not match the expected number of params',
          error_data: {
            details: 'body: number of localizable_params (3) does not match the expected number of params (2)'
          }
        }
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    described_class.new(delivery: delivery).call

    expect(delivery.reload).to have_attributes(
      status: 'failed',
      error_code: '132000',
      error_message: '(#132000) Number of parameters does not match the expected number of params - ' \
                     'body: number of localizable_params (3) does not match the expected number of params (2)',
      meta_http_status: 400,
      template_components: []
    )
  end

  it 'preserves the original failure message when detailed diagnostics are disabled' do
    stub_request(:post, messages_url).to_return(
      status: 400,
      body: {
        error: {
          code: 132_000,
          message: '(#132000) Number of parameters does not match the expected number of params',
          error_data: {
            details: 'body: number of localizable_params (3) does not match the expected number of params (2)'
          }
        }
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    described_class.new(delivery: delivery).call

    expect(delivery.reload).to have_attributes(
      status: 'failed',
      error_code: '132000',
      error_message: '(#132000) Number of parameters does not match the expected number of params',
      meta_http_status: 400
    )
  end

  it 'marks a transport timeout as uncertain instead of resending automatically' do
    stub_request(:post, messages_url).to_timeout

    described_class.new(delivery: delivery).call

    expect(delivery.reload).to have_attributes(
      status: 'uncertain',
      error_code: 'delivery_result_uncertain',
      attempts_count: 1,
      template_components: []
    )
  end

  it 'reschedules a rate-limited delivery without calling Meta' do
    allow(Redis::Alfred).to receive(:set).and_return(nil)
    allow(Redis::Alfred).to receive(:incr).and_return(11)

    expect do
      described_class.new(delivery: delivery).call
    end.to have_enqueued_job(Ibsoft::ExternalMessaging::SendDeliveryJob)

    expect(delivery.reload).to have_attributes(status: 'queued', attempts_count: 0)
    expect(a_request(:post, messages_url)).not_to have_been_made
  end

  it 'keeps a delivery queued when Redis fails before the Meta request' do
    allow(Redis::Alfred).to receive(:set).and_raise(Redis::BaseConnectionError)

    described_class.new(delivery: delivery).call

    expect(delivery.reload).to have_attributes(
      status: 'queued',
      attempts_count: 0,
      enqueued_at: nil
    )
    expect(a_request(:post, messages_url)).not_to have_been_made
  end

  it 'materializes a protected PIX key only for the Meta request and clears it afterwards', :aggregate_failures do
    extracted = Ibsoft::ExternalMessaging::OrderPixSecret.extract(
      [
        {
          'type' => 'button',
          'parameters' => [
            {
              'action' => {
                'order_details' => {
                  'payment_settings' => [
                    {
                      'type' => 'pix_dynamic_code',
                      'pix_dynamic_code' => {
                        'code' => 'PIX-CODE',
                        'merchant_name' => 'IBSoft Cloud',
                        'key' => '12345678000199',
                        'key_type' => 'CNPJ'
                      }
                    }
                  ]
                }
              }
            }
          ]
        }
      ]
    )
    pix_delivery = create(
      :ibsoft_external_message_delivery,
      template_components: extracted.components,
      order_pix_key: extracted.key
    )
    pix_url = "https://graph.facebook.com/v22.0/#{pix_delivery.inbox.channel.provider_config['phone_number_id']}/messages"
    request = stub_request(:post, pix_url).with do |meta_request|
      JSON.parse(meta_request.body).to_json.include?('12345678000199')
    end.to_return(
      status: 200,
      body: { messages: [{ id: 'wamid.external-pix' }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    described_class.new(delivery: pix_delivery).call

    expect(request).to have_been_requested.once
    expect(pix_delivery.reload).to have_attributes(
      status: 'accepted',
      order_pix_key: nil,
      template_components: []
    )
  end
end

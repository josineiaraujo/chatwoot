require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::MetaTemplateClient do
  let(:channel) do
    create(
      :channel_whatsapp,
      provider: 'whatsapp_cloud',
      provider_config: {
        'api_key' => 'meta-token',
        'phone_number_id' => 'phone-number-id'
      },
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:broadcast) do
    create(
      :ibsoft_message_broadcast,
      account: channel.account,
      inbox: channel.inbox,
      template_name: 'aviso_manutencao',
      template_language: 'pt_BR'
    )
  end
  let(:recipient) do
    create(
      :ibsoft_message_broadcast_recipient,
      broadcast: broadcast,
      primary_phone: '+5575982479788'
    )
  end
  let(:candidate) do
    Ibsoft::MessageBroadcast::RecipientPhoneCandidates::Candidate.new(
      kind: 'primary',
      phone_number: '+5575982479788',
      source_id: '5575982479788'
    )
  end
  let(:messages_url) do
    phone_number_id = channel.provider_config.fetch('phone_number_id')
    "https://graph.facebook.com/v22.0/#{phone_number_id}/messages"
  end
  let(:processor) { instance_double(Whatsapp::TemplateProcessorService) }

  before do
    allow(GlobalConfigService).to receive(:load)
      .with('WHATSAPP_API_VERSION', 'v22.0')
      .and_return('v22.0')
    allow(Whatsapp::TemplateProcessorService).to receive(:new).and_return(processor)
    allow(processor).to receive(:call).and_return(
      [
        'aviso_manutencao',
        nil,
        'pt_BR',
        [{ type: 'body', parameters: [{ type: 'text', text: 'Cliente' }] }]
      ]
    )
  end

  it 'posts a normalized template directly to Meta' do
    request = stub_request(:post, messages_url).with do |meta_request|
      body = JSON.parse(meta_request.body)
      body['to'] == '5575982479788' &&
        body.dig('template', 'name') == 'aviso_manutencao' &&
        body.dig('template', 'language', 'code') == 'pt_BR'
    end.to_return(
      status: 200,
      body: { messages: [{ id: 'wamid.broadcast-1' }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    result = described_class.new(broadcast: broadcast, recipient: recipient).call(candidate)

    expect(request).to have_been_requested.once
    expect(result).to have_attributes(message_id: 'wamid.broadcast-1', http_status: 200)
  end

  it 'classifies a client rejection as eligible for fallback' do
    stub_request(:post, messages_url).to_return(
      status: 400,
      body: { error: { code: 131_026, message: 'Message undeliverable' } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    expect do
      described_class.new(broadcast: broadcast, recipient: recipient).call(candidate)
    end.to raise_error(Ibsoft::MessageBroadcast::MetaTemplateClient::RejectedError) { |error|
      expect(error).to be_fallback_eligible
      expect(error).to have_attributes(code: '131026', http_status: 400)
    }
  end

  it 'classifies a timeout as uncertain and ineligible for fallback' do
    stub_request(:post, messages_url).to_timeout

    expect do
      described_class.new(broadcast: broadcast, recipient: recipient).call(candidate)
    end.to raise_error(Ibsoft::MessageBroadcast::MetaTemplateClient::UncertainError) { |error|
      expect(error).not_to be_fallback_eligible
      expect(error.code).to eq('delivery_result_uncertain')
    }
  end

  it 'classifies a server error as uncertain and ineligible for fallback' do
    stub_request(:post, messages_url).to_return(
      status: 503,
      body: { error: { code: 2, message: 'Service temporarily unavailable' } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    expect do
      described_class.new(broadcast: broadcast, recipient: recipient).call(candidate)
    end.to raise_error(Ibsoft::MessageBroadcast::MetaTemplateClient::UncertainError) { |error|
      expect(error).not_to be_fallback_eligible
      expect(error).to have_attributes(code: 'delivery_result_uncertain', http_status: 503)
    }
  end

  it 'classifies a successful response without a message id as uncertain' do
    stub_request(:post, messages_url).to_return(
      status: 200,
      body: { messages: [] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    expect do
      described_class.new(broadcast: broadcast, recipient: recipient).call(candidate)
    end.to raise_error(Ibsoft::MessageBroadcast::MetaTemplateClient::UncertainError) { |error|
      expect(error).not_to be_fallback_eligible
      expect(error).to have_attributes(code: 'delivery_result_uncertain', http_status: 200)
    }
  end

  it 'fails before an external request when the channel is misconfigured' do
    expected_messages_url = messages_url
    channel.update!(provider_config: {})

    expect do
      described_class.new(broadcast: broadcast, recipient: recipient).call(candidate)
    end.to raise_error(Ibsoft::MessageBroadcast::MetaTemplateClient::ConfigurationError)

    expect(a_request(:post, expected_messages_url)).not_to have_been_made
  end
end

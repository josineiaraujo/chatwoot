require 'rails_helper'

RSpec.describe Ibsoft::MetaTemplates::MediaUploader do
  let(:channel) do
    create(
      :channel_whatsapp,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:file) do
    Rack::Test::UploadedFile.new(
      Rails.root.join('spec/assets/avatar.png'),
      'image/png'
    )
  end

  before do
    # The native factory replaces cloud credentials with deterministic defaults.
    # rubocop:disable Rails/SkipsModelValidations
    channel.update_column(:provider_config, {
                            'api_key' => 'secret-token',
                            'business_account_id' => 'waba-123',
                            'phone_number_id' => 'phone-123'
                          })
    # rubocop:enable Rails/SkipsModelValidations
    allow(GlobalConfigService).to receive(:load)
      .with('WHATSAPP_APP_ID', '')
      .and_return('app-123')
    allow(GlobalConfigService).to receive(:load)
      .with('WHATSAPP_API_VERSION', 'v22.0')
      .and_return('v22.0')
  end

  it 'creates a resumable session and streams the file to Meta' do
    session_request = stub_request(
      :post,
      'https://graph.facebook.com/v22.0/app-123/uploads'
    ).with(
      headers: { 'Authorization' => 'OAuth secret-token' },
      query: hash_including(
        'file_name' => 'avatar.png',
        'file_type' => 'image/png'
      )
    ).to_return(
      status: 200,
      body: { id: 'upload:c2Vzc2lvbi0xMjM=?sig=meta-signature_123' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    upload_response = Net::HTTPOK.new('1.1', '200', 'OK')
    allow(upload_response).to receive(:body)
      .and_return({ h: 'meta-media-handle' }.to_json)
    http = instance_double(Net::HTTP)
    allow(http).to receive(:request) do |request|
      expect(request['Authorization']).to eq('OAuth secret-token')
      expect(request['Content-Type']).to eq('image/png')
      expect(request['file_offset']).to eq('0')
      expect(request.body_stream).to be_a(File)
      upload_response
    end
    allow(Net::HTTP).to receive(:start).and_yield(http)

    result = described_class.new(channel: channel, file: file).call

    expect(session_request).to have_been_requested.once
    expect(result).to include(
      handle: 'meta-media-handle',
      filename: 'avatar.png',
      content_type: 'image/png'
    )
  end

  it 'rejects unsupported content before contacting Meta' do
    unsupported_file = Rack::Test::UploadedFile.new(
      Rails.root.join('spec/assets/contacts.csv'),
      'text/csv'
    )

    operation = lambda do
      described_class.new(channel: channel, file: unsupported_file).call
    end

    expect(&operation).to raise_error(described_class::Error) do |error|
      expect(error.code).to eq('unsupported_file')
    end
    expect(a_request(:any, /graph\.facebook\.com/)).not_to have_been_made
  end

  it 'rejects an upload session pointing outside the Meta upload namespace' do
    stub_request(
      :post,
      'https://graph.facebook.com/v22.0/app-123/uploads'
    ).with(
      query: hash_including(
        'file_name' => 'avatar.png',
        'file_type' => 'image/png'
      )
    ).to_return(
      status: 200,
      body: { id: 'https://example.com/upload:session-123' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    operation = lambda do
      described_class.new(channel: channel, file: file).call
    end

    expect(Net::HTTP).not_to receive(:start)
    expect(&operation).to raise_error(described_class::Error) do |error|
      expect(error.code).to eq('session_failed')
    end
  end

  it 'rejects files above the limit before opening an upload session' do
    oversized_file = instance_double(
      ActionDispatch::Http::UploadedFile,
      content_type: 'image/png',
      size: 6.megabytes,
      original_filename: 'large.png'
    )

    operation = lambda do
      described_class.new(channel: channel, file: oversized_file).call
    end

    expect(&operation).to raise_error(described_class::Error) do |error|
      expect(error.code).to eq('file_too_large')
    end
    expect(a_request(:any, /graph\.facebook\.com/)).not_to have_been_made
  end

  it 'rejects the upload when the WhatsApp Embedded app ID is missing' do
    allow(GlobalConfigService).to receive(:load)
      .with('WHATSAPP_APP_ID', '')
      .and_return(nil)

    operation = lambda do
      described_class.new(channel: channel, file: file).call
    end

    expect(&operation).to raise_error(described_class::Error) do |error|
      expect(error.code).to eq('missing_app_id')
    end
    expect(a_request(:any, /graph\.facebook\.com/)).not_to have_been_made
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::MetaTemplates::Client do
  let(:channel) do
    create(
      :channel_whatsapp,
      provider: 'whatsapp_cloud',
      provider_config: {
        'api_key' => 'secret-token',
        'business_account_id' => 'waba-123',
        'phone_number_id' => 'phone-123'
      },
      sync_templates: false,
      validate_provider_config: false
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
      .with('WHATSAPP_API_VERSION', 'v22.0')
      .and_return('v22.0')
  end

  it 'paginates the Meta catalog using cursors' do
    first = stub_request(
      :get,
      %r{https://graph\.facebook\.com/v22\.0/waba-123/message_templates}
    ).with(query: hash_including('limit' => '100')).to_return(
      status: 200,
      body: {
        data: [{ id: '1', name: 'first' }],
        paging: { cursors: { after: 'cursor-2' }, next: 'present' }
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    ).then.to_return(
      status: 200,
      body: {
        data: [{ id: '2', name: 'second' }],
        paging: { cursors: { after: 'cursor-3' } }
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    result = described_class.new(channel).list_templates

    expect(result.pluck('id')).to eq(%w[1 2])
    expect(first).to have_been_requested.twice
    expect(
      a_request(:get, %r{/message_templates}).with(
        query: hash_including('after' => 'cursor-2')
      )
    ).to have_been_made.once
    expect(
      a_request(:get, %r{/message_templates}).with do |request|
        fields = Rack::Utils.parse_query(request.uri.query)
                           .fetch('fields')
                           .split(',')
        %w[last_updated_time sub_category display_format].all? do |field|
          fields.include?(field)
        end
      end
    ).to have_been_made.twice
  end

  it 'uses an authorization header and never places the token in the URL' do
    request = stub_request(
      :post,
      'https://graph.facebook.com/v22.0/waba-123/message_templates'
    ).with(
      headers: { 'Authorization' => 'Bearer secret-token' },
      body: hash_including('name' => 'modelo')
    ).to_return(
      status: 200,
      body: { id: 'template-1' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    described_class.new(channel).create_template('name' => 'modelo')

    expect(request).to have_been_requested.once
    expect(a_request(:post, /secret-token/)).not_to have_been_made
  end

  it 'maps Meta errors to a stable service error' do
    stub_request(
      :get,
      %r{https://graph\.facebook\.com/v22\.0/waba-123/message_templates}
    ).to_return(
      status: 400,
      body: {
        error: {
          code: 100,
          error_user_msg: 'Invalid template'
        }
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    operation = -> { described_class.new(channel).list_templates }

    expect(&operation).to raise_error(described_class::Error) do |error|
      expect(error.code).to eq('100')
      expect(error.http_status).to eq(400)
      expect(error.message).to eq('Invalid template')
    end
  end

  it 'rejects channels without a WABA credential set' do
    channel.provider_config = {}

    expect do
      described_class.new(channel)
    end.to raise_error(described_class::Error, /credenciais|credentials/i)
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::Endpoint do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false
    )
  end

  it 'stores only the token digest and authenticates an active endpoint', :aggregate_failures do
    endpoint = described_class.new(
      account: account,
      inbox: channel.inbox,
      created_by: admin,
      name: 'ERP principal'
    )
    raw_token = endpoint.issue_token
    endpoint.save!

    expect(endpoint.token_digest).to eq(described_class.digest_token(raw_token))
    expect(endpoint.token_digest).not_to include(raw_token)
    expect(described_class.authenticate(raw_token)).to eq(endpoint)

    endpoint.update!(active: false)
    expect(described_class.authenticate(raw_token)).to be_nil
  end

  it 'rejects an inbox from another account' do
    endpoint = build(
      :ibsoft_external_message_endpoint,
      account: account,
      inbox: create(:inbox)
    )

    expect(endpoint).not_to be_valid
    expect(endpoint.errors[:inbox]).to be_present
  end

  it 'accepts only registered instance types' do
    endpoint = build(
      :ibsoft_external_message_endpoint,
      account: account,
      whatsapp_channel: channel,
      instance_type: 'unknown'
    )

    expect(endpoint).not_to be_valid
    expect(endpoint.errors[:instance_type]).to be_present
  end

  it 'uses the most restrictive active endpoint limit for a shared channel' do
    endpoint = create(
      :ibsoft_external_message_endpoint,
      account: account,
      whatsapp_channel: channel,
      rate_limit_per_second: 20
    )
    create(
      :ibsoft_external_message_endpoint,
      account: account,
      whatsapp_channel: channel,
      rate_limit_per_second: 7
    )
    create(
      :ibsoft_external_message_endpoint,
      account: account,
      whatsapp_channel: channel,
      rate_limit_per_second: 3,
      active: false
    )

    expect(endpoint.effective_rate_limit_per_second).to eq(7)
  end

  it 'normalizes PIX defaults without exposing the protected key in its payload', :aggregate_failures do
    endpoint = create(
      :ibsoft_external_message_endpoint,
      account: account,
      created_by: admin,
      whatsapp_channel: channel,
      order_pix_merchant_name: '  IBSoft Cloud  ',
      order_pix_key: '  12345678000199  ',
      order_pix_key_type: 'cnpj'
    )

    expect(endpoint).to have_attributes(
      order_pix_merchant_name: 'IBSoft Cloud',
      order_pix_key: '12345678000199',
      order_pix_key_type: 'CNPJ'
    )
    expect(endpoint).to be_order_defaults_configured
    expect(endpoint.payload[:order_defaults]).to include(
      merchant_name: 'IBSoft Cloud',
      key_type: 'CNPJ',
      key_configured: true,
      key_hint: '****0199'
    )
    expect(endpoint.payload.dig(:order_defaults, :messages).keys).to match_array(
      Ibsoft::ExternalMessaging::OrderUpdateMessageCatalog::KEYS
    )
    expect(endpoint.payload.to_json).not_to include('12345678000199')
  end

  it 'normalizes and validates configurable order update messages' do
    endpoint = create(
      :ibsoft_external_message_endpoint,
      account: account,
      whatsapp_channel: channel,
      order_update_messages: {
        payment_captured: '  Pagamento {{reference_id}} confirmado.  ',
        order_completed: ''
      }
    )

    expect(endpoint.order_update_messages).to eq(
      'payment_captured' => 'Pagamento {{reference_id}} confirmado.'
    )
    expect(endpoint.payload.dig(:order_defaults, :messages, 'payment_captured')).to eq(
      'Pagamento {{reference_id}} confirmado.'
    )

    endpoint.order_update_messages = { unsupported: 'Invalid' }
    expect(endpoint).not_to be_valid
    expect(endpoint.errors[:order_update_messages]).to be_present
  end
end

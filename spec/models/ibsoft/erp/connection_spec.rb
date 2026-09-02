require 'rails_helper'

RSpec.describe Ibsoft::Erp::Connection do
  let(:account) { create(:account) }

  it 'returns providers supported by the private ERP layer' do
    providers = described_class.providers_payload

    expect(providers.pluck(:key)).to contain_exactly('ixc', 'sgp')
    expect(providers.find { |provider| provider[:key] == 'sgp' }[:auth_types]).to contain_exactly('basic', 'token_app')
  end

  it 'does not expose raw credentials in the public payload' do
    connection = build(:ibsoft_erp_connection, account: account)

    expect(connection.payload).not_to include(:credentials)
    expect(connection.payload[:credentials_configured]).to be(true)
  end

  it 'round-trips encrypted credentials without storing their plaintext' do
    skip('encryption keys missing; configure the release-test environment') unless Chatwoot.encryption_configured?

    connection = create(
      :ibsoft_erp_connection,
      account: account,
      credentials: { username: 'integration-user', password: 'private-password' }
    )
    raw_credentials = described_class.connection.select_value(
      described_class.sanitize_sql_array(
        ['SELECT credentials FROM ibsoft_erp_connections WHERE id = ?', connection.id]
      )
    )

    expect(raw_credentials).not_to include('private-password')
    expect(connection.reload.credentials).to eq(
      'username' => 'integration-user',
      'password' => 'private-password'
    )
  end

  it 'allows only one active ERP connection per account' do
    first_connection = create(:ibsoft_erp_connection, account: account, active: true)
    second_connection = create(:ibsoft_erp_connection, account: account, active: true)

    expect(first_connection.reload.active).to be(false)
    expect(second_connection.reload.active).to be(true)
  end

  it 'rejects unsupported authentication for the selected provider' do
    connection = build(
      :ibsoft_erp_connection,
      account: account,
      provider: 'ixc',
      auth_type: 'token_app',
      credentials: { token: 'token', app: 'app' }
    )

    expect(connection).not_to be_valid
    expect(connection.errors[:auth_type]).to be_present
  end

  it 'requires credentials expected by the authentication type' do
    connection = build(
      :ibsoft_erp_connection,
      account: account,
      provider: 'sgp',
      auth_type: 'token_app',
      credentials: { token: 'token' }
    )

    expect(connection).not_to be_valid
    expect(connection.errors[:credentials]).to be_present
  end
end

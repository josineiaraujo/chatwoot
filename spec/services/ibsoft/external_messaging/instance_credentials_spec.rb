require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::InstanceCredentials do
  it 'keeps the SGP token contract unchanged' do
    endpoint = build_stubbed(
      :ibsoft_external_message_endpoint,
      instance_type: 'sgp_generic',
      token_hint: 'ibext_abc...'
    )
    credentials = described_class.new(endpoint: endpoint)

    expect(credentials.public_payload).to eq(
      type: 'token',
      secret_hint: 'ibext_abc...'
    )
    expect(credentials.issued_payload('secret')).to eq(token: 'secret')
  end

  it 'derives a stable IXC username and only reveals the generated password once' do
    endpoint = build_stubbed(
      :ibsoft_external_message_endpoint,
      id: 42,
      instance_type: 'ixc',
      token_hint: 'ibext_xyz...'
    )
    credentials = described_class.new(endpoint: endpoint)

    expect(credentials.public_payload).to eq(
      type: 'username_password',
      username: 'ixc_42',
      secret_hint: 'ibext_xyz...'
    )
    expect(credentials.issued_payload('secret')).to eq(
      credentials: {
        type: 'username_password',
        username: 'ixc_42',
        password: 'secret'
      }
    )
  end
end

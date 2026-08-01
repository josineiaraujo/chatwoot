require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::EndpointAuthenticator do
  let(:password) { 'ixc-secret' }
  let(:endpoint) do
    create(
      :ibsoft_external_message_endpoint,
      instance_type: 'ixc',
      token_digest: Ibsoft::ExternalMessaging::Endpoint.digest_token(password)
    )
  end
  let(:username) do
    Ibsoft::ExternalMessaging::InstanceCredentials.new(endpoint: endpoint).username
  end

  def authenticate(credentials, instance_type: 'ixc')
    described_class.new(instance_type: instance_type, credentials: credentials).call
  end

  def authenticate_family(credentials, family: 'ixc')
    described_class.new(family: family, credentials: credentials).call
  end

  it 'authenticates the generated IXC username and password pair' do
    expect(authenticate({ username: username, password: password })).to eq(endpoint)
  end

  it 'authenticates an IXC endpoint through its shared family route' do
    expect(authenticate_family({ username: username, password: password })).to eq(endpoint)
  end

  it 'rejects an invalid IXC username without exposing which credential failed' do
    expect do
      authenticate({ username: 'another-user', password: password })
    end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) { |error|
      expect(error).to have_attributes(code: 'ixc_unauthorized', http_status: :unauthorized)
    }
  end

  it 'rejects invalid, inactive, and cross-contract credentials' do
    expect do
      authenticate({ username: username, password: 'invalid' })
    end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest)

    endpoint.update!(active: false)
    expect do
      authenticate({ username: username, password: password })
    end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest)

    endpoint.update!(active: true)
    expect do
      authenticate({ token: password }, instance_type: 'sgp_generic')
    end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest)
  end

  it 'rejects a valid endpoint credential from another integration family' do
    sgp_token = 'sgp-secret'
    create(
      :ibsoft_external_message_endpoint,
      token_digest: Ibsoft::ExternalMessaging::Endpoint.digest_token(sgp_token)
    )

    expect do
      authenticate_family({ username: 'ixc_1', password: sgp_token })
    end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) { |error|
      expect(error).to have_attributes(code: 'ixc_unauthorized', http_status: :unauthorized)
    }
  end

  it 'requires exactly one endpoint scope' do
    expect do
      described_class.new(credentials: {})
    end.to raise_error(ArgumentError, 'provide exactly one endpoint scope')

    expect do
      described_class.new(instance_type: 'ixc', family: 'ixc', credentials: {})
    end.to raise_error(ArgumentError, 'provide exactly one endpoint scope')
  end
end

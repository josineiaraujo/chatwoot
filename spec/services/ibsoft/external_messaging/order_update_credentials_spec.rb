require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrderUpdateCredentials do
  def credentials(method: 'GET', authorization: nil, query: {})
    described_class.new(
      method: method,
      authorization: authorization,
      query_parameters: query
    ).call
  end

  it 'extracts SGP credentials from Bearer authentication' do
    expect(
      credentials(method: 'POST', authorization: 'Bearer sgp-secret')
    ).to eq(token: 'sgp-secret')
  end

  it 'accepts the SGP token in the query only for GET compatibility' do
    expect(credentials(query: { token: 'sgp-secret' })).to eq(token: 'sgp-secret')
    expect(credentials(method: 'POST', query: { token: 'sgp-secret' })).to eq(token: nil)
  end

  it 'ignores unsupported and oversized authorization headers' do
    expect(credentials(authorization: 'Basic unsupported')).to eq(token: nil)
    expect(credentials(authorization: "Bearer #{'A' * 5000}")).to eq(token: nil)
  end
end

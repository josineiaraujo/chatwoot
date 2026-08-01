require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrderUpdateInboundRequest do
  def parse(family:, **overrides)
    request_attributes = {
      method: 'GET',
      authorization: '',
      query_parameters: {},
      raw_body: '',
      media_type: '',
      content_type: ''
    }.merge(overrides)

    described_class.new(
      family: family,
      request_attributes: request_attributes
    ).call
  end

  it 'keeps the SGP order contract as direct fields plus token' do
    result = parse(
      family: 'sgp',
      query_parameters: { fatura_id: '9388', status: 'pago', token: 'sgp-secret' }
    )

    expect(result).to have_attributes(
      credentials: { token: 'sgp-secret' },
      fields: { 'fatura_id' => '9388', 'status' => 'pago' },
      recipient: nil
    )
  end

  it 'parses IXC order updates exclusively through user, pw, dest, and text' do
    result = parse(
      family: 'ixc',
      query_parameters: {
        user: 'ixc_15',
        pw: 'ixc-secret',
        dest: '55 (75) 98247-9788',
        text: '[fatura_id]=9388||[status]=pago'
      }
    )

    expect(result).to have_attributes(
      credentials: { username: 'ixc_15', password: 'ixc-secret' },
      fields: { 'fatura_id' => '9388', 'status' => 'pago' },
      recipient: '5575982479788'
    )
  end

  it 'accepts the IXC envelope as a JSON POST without changing its semantic text' do
    result = parse(
      family: 'ixc',
      method: 'POST',
      raw_body: {
        user: 'ixc_15',
        pw: 'ixc-secret',
        dest: '5575982479788',
        text: '[reference_id]=9388||[payment_status]=captured'
      }.to_json,
      media_type: 'application/json',
      content_type: 'application/json'
    )

    expect(result.fields).to eq(
      'reference_id' => '9388',
      'payment_status' => 'captured'
    )
  end
end

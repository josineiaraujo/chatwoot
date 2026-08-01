require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::InboundRequestParser do
  def invalid_request
    yield
    raise 'Expected Ibsoft::ExternalMessaging::InvalidRequest'
  rescue Ibsoft::ExternalMessaging::InvalidRequest => e
    e
  end

  it 'parses the required msg and to query parameters' do
    result = described_class.new(
      method: 'GET',
      parameters: {
        to: '5575982479788',
        msg: '[template_name]=aviso||[body.1]=Maria'
      }
    ).call

    expect(result).to eq(
      recipient: '5575982479788',
      fields: {
        'template_name' => 'aviso',
        'body.1' => 'Maria'
      },
      credentials: { token: nil }
    )
  end

  it 'keeps compatibility with msg copied from the generic curl body' do
    result = described_class.new(
      method: 'GET',
      parameters: {
        to: '5575982479788',
        msg: "curl --data-raw '[template_name]=aviso||[body.1]=Maria'"
      }
    ).call

    expect(result[:fields]).to include(
      'template_name' => 'aviso',
      'body.1' => 'Maria'
    )
  end

  it 'rejects requests without msg' do
    error = invalid_request do
      described_class.new(
        method: 'GET',
        parameters: { to: '5575982479788' }
      ).call
    end

    expect(error.code).to eq('payload_required')
  end

  it 'rejects methods outside the public contract' do
    error = invalid_request do
      described_class.new(
        method: 'POST',
        parameters: {
          to: '5575982479788',
          msg: '[template_name]=aviso'
        }
      ).call
    end

    expect(error).to have_attributes(
      code: 'method_not_allowed',
      http_status: :method_not_allowed
    )
  end
end

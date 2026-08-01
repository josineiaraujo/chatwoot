require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrderStatusRequestParser do
  def parse(**attributes)
    described_class.new(
      method: 'GET',
      media_type: nil,
      raw_body: '',
      query_parameters: {},
      **attributes
    ).call
  end

  it 'parses scalar GET parameters and removes routing credentials' do
    expect(
      parse(
        query_parameters: {
          fatura_id: '9388',
          status: 'pago',
          token: 'secret',
          controller: 'ignored'
        }
      )
    ).to eq('fatura_id' => '9388', 'status' => 'pago')
  end

  it 'parses the bracket contract from a text body' do
    expect(
      parse(
        method: 'POST',
        media_type: 'text/plain',
        raw_body: '[fatura_id]=9388||[status]=pago'
      )
    ).to eq('fatura_id' => '9388', 'status' => 'pago')
  end

  it 'parses a JSON object with scalar values' do
    expect(
      parse(
        method: 'POST',
        media_type: 'application/json',
        raw_body: JSON.generate(fatura_id: 9388, status: 'pago')
      )
    ).to eq('fatura_id' => '9388', 'status' => 'pago')
  end

  it 'rejects arrays and unsupported media types' do
    expect do
      parse(method: 'POST', media_type: 'application/json', raw_body: '[]')
    end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) { |error|
      expect(error.code).to eq('order_update_json_invalid')
    }

    expect do
      parse(method: 'POST', media_type: 'application/x-www-form-urlencoded', raw_body: 'status=pago')
    end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) { |error|
      expect(error.http_status).to eq(:unsupported_media_type)
    }
  end
end

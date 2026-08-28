require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::StandardInboundRequestParser do
  let(:token) { 'ibext_standard_secret' }
  let(:payload) do
    [
      '[template_name]=aviso',
      '[template_language]=pt_BR',
      '[to]=+55 (75) 98247-9788',
      '[tipo-canal]=whatsapp-cloud',
      '[body.nome]=José'
    ].join('||')
  end

  def parse(**overrides)
    described_class.new(
      method: 'POST',
      authorization: "Bearer #{token}",
      raw_body: payload,
      media_type: 'text/plain',
      **overrides
    ).call
  end

  def error_for(**arguments)
    parse(**arguments)
    raise 'Expected Ibsoft::ExternalMessaging::InvalidRequest'
  rescue Ibsoft::ExternalMessaging::InvalidRequest => e
    e
  end

  it 'parses the standard body, normalizes the recipient, and extracts bearer credentials' do
    expect(parse).to eq(
      recipient: '5575982479788',
      fields: {
        'template_name' => 'aviso',
        'template_language' => 'pt_BR',
        'tipo-canal' => 'whatsapp-cloud',
        'body.nome' => 'José'
      },
      credentials: { token: token }
    )
  end

  it 'rejects unsupported methods and media types' do
    method_error = error_for(method: 'GET')
    media_type_error = error_for(media_type: 'application/json')

    expect(method_error).to have_attributes(
      code: 'standard_method_not_allowed',
      http_status: :method_not_allowed
    )
    expect(media_type_error).to have_attributes(
      code: 'standard_content_type_invalid',
      http_status: :unsupported_media_type
    )
  end

  it 'requires one bounded bearer credential and ignores query-style credentials' do
    missing = error_for(authorization: '')
    malformed = error_for(authorization: "Basic #{token}")
    oversized = error_for(authorization: "Bearer #{'a' * (4.kilobytes + 1)}")

    expect([missing.code, malformed.code, oversized.code]).to all(eq('unauthorized'))
    expect([missing.http_status, malformed.http_status, oversized.http_status]).to all(eq(:unauthorized))
  end

  it 'rejects empty, oversized, and invalid UTF-8 bodies' do
    empty = error_for(raw_body: '')
    oversized = error_for(raw_body: "[to]=5575982479788||[body.value]=#{'a' * 64.kilobytes}")
    invalid_body = "[to]=5575982479788||[body.value]=\xFF".b
    invalid_encoding = error_for(raw_body: invalid_body)

    expect(empty.code).to eq('payload_required')
    expect(oversized.code).to eq('standard_payload_too_large')
    expect(invalid_encoding.code).to eq('payload_invalid_encoding')
  end

  it 'accepts only the documented bracket format with double-pipe separators' do
    legacy = error_for(raw_body: '{template_name}=[aviso],{to}=[5575982479788]')
    single_pipe = error_for(raw_body: '[template_name]=aviso|[to]=5575982479788')

    expect(legacy.code).to eq('payload_invalid_format')
    expect(single_pipe.code).to eq('payload_invalid_separator')
  end

  it 'requires the documented to field and rejects invalid recipients' do
    missing = error_for(raw_body: '[template_name]=aviso')
    invalid = error_for(raw_body: '[template_name]=aviso||[to]=000')
    legacy_alias = error_for(
      raw_body: '[template_name]=aviso||[recipient]=5575982479788'
    )

    expect(missing.code).to eq('standard_recipient_required')
    expect(invalid.code).to eq('recipient_invalid')
    expect(legacy_alias.code).to eq('standard_recipient_required')
  end
end

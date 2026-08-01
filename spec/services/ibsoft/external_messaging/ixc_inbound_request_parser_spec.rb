require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::IxcInboundRequestParser do
  let(:text) do
    '[template_name]=aviso||[body.nome]=José||[order.total]=64,99'
  end
  let(:envelope) do
    {
      user: 'usuario-ixc',
      pw: 'senha-ixc',
      dest: '+55 (75) 98247-9788',
      text: text
    }
  end

  def parse(method: 'GET', query: envelope, body: '', content_type: '')
    described_class.new(
      method: method,
      query_parameters: query,
      raw_body: body,
      content_type: content_type
    ).call
  end

  def error_for(**arguments)
    parse(**arguments)
    raise 'Expected Ibsoft::ExternalMessaging::InvalidRequest'
  rescue Ibsoft::ExternalMessaging::InvalidRequest => e
    e
  end

  it 'parses the IXC GET envelope, normalizes dest, and preserves text values' do
    result = parse

    expect(result).to eq(
      recipient: '5575982479788',
      fields: {
        'template_name' => 'aviso',
        'body.nome' => 'José',
        'order.total' => '64,99'
      },
      credentials: {
        username: 'usuario-ixc',
        password: 'senha-ixc'
      }
    )
  end

  it 'accepts form and JSON POST bodies' do
    form_result = parse(
      method: 'POST',
      query: {},
      body: Rack::Utils.build_nested_query(envelope),
      content_type: 'application/x-www-form-urlencoded; charset=UTF-8'
    )
    json_result = parse(
      method: 'POST',
      query: {},
      body: envelope.to_json,
      content_type: 'application/vnd.ixc+json'
    )

    expect(form_result).to eq(json_result)
    expect(json_result[:recipient]).to eq('5575982479788')
  end

  it 'accepts identical fields split between query and body' do
    result = parse(
      method: 'POST',
      query: envelope.slice(:user, :pw),
      body: envelope.slice(:pw, :dest, :text).to_json,
      content_type: 'application/json'
    )

    expect(result[:credentials]).to include(username: 'usuario-ixc')
  end

  it 'rejects conflicting fields between query and body' do
    error = error_for(
      method: 'POST',
      query: envelope,
      body: { user: 'outro-usuario' }.to_json,
      content_type: 'application/json'
    )

    expect(error.code).to eq('ixc_field_conflict')
  end

  it 'validates methods and POST content types' do
    method_error = error_for(method: 'PUT')
    content_type_error = error_for(
      method: 'POST',
      query: {},
      body: 'payload',
      content_type: 'text/plain'
    )

    expect(method_error).to have_attributes(
      code: 'ixc_method_not_allowed',
      http_status: :method_not_allowed
    )
    expect(content_type_error).to have_attributes(
      code: 'ixc_content_type_invalid',
      http_status: :unsupported_media_type
    )
  end

  it 'validates required scalar fields and their limits' do
    missing_error = error_for(query: envelope.except(:user))
    scalar_error = error_for(query: envelope.merge(user: ['invalid']))
    username_error = error_for(query: envelope.merge(user: 'a' * 257))
    password_error = error_for(query: envelope.merge(pw: 'a' * 1025))
    destination_error = error_for(query: envelope.merge(dest: '1' * 65))
    text_error = error_for(query: envelope.merge(text: 'a' * (64.kilobytes + 1)))

    expect(missing_error.code).to eq('ixc_field_required')
    expect(scalar_error.code).to eq('ixc_scalar_fields_required')
    expect(username_error.code).to eq('ixc_field_too_large')
    expect(password_error.code).to eq('ixc_field_too_large')
    expect(destination_error.code).to eq('ixc_field_too_large')
    expect(text_error.code).to eq('ixc_text_too_large')
  end

  it 'rejects malformed JSON and invalid UTF-8 text' do
    json_error = error_for(
      method: 'POST',
      query: {},
      body: '{invalid',
      content_type: 'application/json'
    )
    invalid_text = text.dup.force_encoding(Encoding::ASCII_8BIT) + "\xFF".b
    encoding_error = error_for(query: envelope.merge(text: invalid_text))

    expect(json_error.code).to eq('ixc_json_invalid')
    expect(encoding_error.code).to eq('ixc_text_invalid_encoding')
  end

  it 'accepts a matching embedded recipient and removes recipient aliases from template fields' do
    aliased_text = "#{text}||[to]=5575982479788||[recipient]=+55 75 98247-9788"
    result = parse(query: envelope.merge(text: aliased_text))

    expect(result[:recipient]).to eq('5575982479788')
    expect(result[:fields]).not_to include('to', 'recipient')
  end

  it 'rejects conflicting or invalid recipients' do
    conflict = error_for(
      query: envelope.merge(text: "#{text}||[to]=5511999999999")
    )
    invalid = error_for(query: envelope.merge(dest: '000'))

    expect(conflict.code).to eq('ixc_recipient_conflict')
    expect(invalid.code).to eq('ixc_recipient_invalid')
  end
end

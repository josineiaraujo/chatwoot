require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::FieldPayloadParser do
  subject(:parser) { described_class.new }

  def invalid_request
    yield
    raise 'Expected Ibsoft::ExternalMessaging::InvalidRequest'
  rescue Ibsoft::ExternalMessaging::InvalidRequest => e
    e
  end

  it 'parses the semantic pipe format without changing UTF-8 values' do
    result = parser.call(
      '[template_name]=aviso_fatura||[body.nome_cliente]=José Silva||[order.total]=64,99'
    )

    expect(result).to eq(
      'template_name' => 'aviso_fatura',
      'body.nome_cliente' => 'José Silva',
      'order.total' => '64,99'
    )
  end

  it 'parses the legacy brace format' do
    result = parser.call('{template_name}=[aviso], {body.1}=[Primeiro]')

    expect(result).to eq(
      'template_name' => 'aviso',
      'body.1' => 'Primeiro'
    )
  end

  it 'rejects duplicated fields' do
    error = invalid_request do
      parser.call('[template_name]=primeiro||[template_name]=segundo')
    end

    expect(error.code).to eq('field_duplicated')
  end

  it 'rejects malformed separators' do
    error = invalid_request do
      parser.call('[template_name]=aviso||texto inválido')
    end

    expect(error.code).to eq('payload_invalid_format')
  end
end

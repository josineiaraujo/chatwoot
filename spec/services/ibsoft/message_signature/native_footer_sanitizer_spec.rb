# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ibsoft::MessageSignature::NativeFooterSanitizer do
  it 'removes the exact native footer and its delimiter' do
    content = "Olá!\n\n--\n\nObrigado, **Maria**"

    result = described_class.new(
      content: content,
      native_signature: 'Obrigado, **Maria**'
    ).call

    expect(result).to eq('Olá!')
  end

  it 'removes the plain-text variant produced for channels without markdown' do
    content = "Olá!\n\n--\n\nObrigado, Maria"

    result = described_class.new(
      content: content,
      native_signature: 'Obrigado, **Maria**'
    ).call

    expect(result).to eq('Olá!')
  end

  it 'preserves message content when the footer does not exactly match' do
    content = "Olá!\n\n--\n\nOutro texto"

    result = described_class.new(content: content, native_signature: 'Obrigado').call

    expect(result).to eq(content)
  end
end

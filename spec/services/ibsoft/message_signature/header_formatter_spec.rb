# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ibsoft::MessageSignature::HeaderFormatter do
  it 'prepends the normalized agent name in bold' do
    result = described_class.new(content: 'Olá!', agent_name: "  Maria   Silva\n").call

    expect(result).to eq("**Maria Silva**\n\nOlá!")
  end

  it 'escapes markdown control characters in the agent name' do
    result = described_class.new(content: 'Olá!', agent_name: 'Maria *Suporte*').call

    expect(result).to eq("**Maria \\*Suporte\\***\n\nOlá!")
  end

  it 'does not duplicate an existing header' do
    content = "**Maria**\n\nOlá!"

    expect(described_class.new(content: content, agent_name: 'Maria').call).to eq(content)
  end

  it 'does not turn an attachment-only message into a textual message' do
    expect(described_class.new(content: '', agent_name: 'Maria').call).to eq('')
  end

  it 'preserves valid content close to the model limit instead of making it invalid' do
    content = 'a' * 149_999

    expect(described_class.new(content: content, agent_name: 'Maria').call).to eq(content)
  end
end

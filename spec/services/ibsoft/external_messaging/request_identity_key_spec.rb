require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::RequestIdentityKey do
  it 'returns a stable internal key for the same order' do
    fields = {
      'template_name' => 'invoice_order',
      'order.reference_id' => 'INVOICE-42'
    }

    first = described_class.new(fields: fields).call
    second = described_class.new(fields: fields).call

    expect(first).to start_with('order-')
    expect(second).to eq(first)
  end

  it 'returns a unique internal key for messages without an order' do
    fields = { 'template_name' => 'notice' }

    first = described_class.new(fields: fields).call
    second = described_class.new(fields: fields).call

    expect(first).to start_with('request-')
    expect(second).not_to eq(first)
  end
end

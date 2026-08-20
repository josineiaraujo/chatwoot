require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrderUpdateEventKey do
  it 'maps every supported order and payment state to its configuration key', :aggregate_failures do
    expect(described_class.call(order_status: 'pending', payment_status: nil)).to eq('order_pending')
    expect(described_class.call(order_status: 'processing', payment_status: nil)).to eq('order_processing')
    expect(described_class.call(order_status: 'partially_shipped', payment_status: nil))
      .to eq('order_partially_shipped')
    expect(described_class.call(order_status: 'shipped', payment_status: nil)).to eq('order_shipped')
    expect(described_class.call(order_status: 'completed', payment_status: nil)).to eq('order_completed')
    expect(described_class.call(order_status: 'canceled', payment_status: nil)).to eq('order_canceled')
    expect(described_class.call(order_status: nil, payment_status: 'pending')).to eq('payment_pending')
    expect(described_class.call(order_status: nil, payment_status: 'captured')).to eq('payment_captured')
    expect(described_class.call(order_status: nil, payment_status: 'failed')).to eq('payment_failed')
    expect(described_class.call(order_status: 'completed', payment_status: 'captured'))
      .to eq('captured_and_completed')
  end
end

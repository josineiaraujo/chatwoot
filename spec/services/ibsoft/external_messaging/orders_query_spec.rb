require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrdersQuery do
  let(:account) { create(:account) }
  let(:endpoint) { create(:ibsoft_external_message_endpoint, account: account) }

  def create_order(reference_id:, recipient:, created_at:, order_status: 'pending', payment_status: nil)
    delivery = create(
      :ibsoft_external_message_delivery,
      endpoint: endpoint,
      template_type: 'order',
      order_reference_id: reference_id,
      recipient: recipient,
      status: 'accepted',
      meta_message_id: "wamid.#{reference_id}",
      created_at: created_at
    )
    create(
      :ibsoft_external_message_order,
      opening_delivery: delivery,
      reference_id: reference_id,
      order_status: order_status,
      payment_status: payment_status,
      created_at: created_at
    )
  end

  it 'combines recipient, date and status filters inside the endpoint tenant' do
    matching = create_order(
      reference_id: 'invoice-match',
      recipient: '5575982479788',
      created_at: Time.zone.parse('2026-07-10 12:00:00'),
      payment_status: 'captured'
    )
    create_order(
      reference_id: 'invoice-other-phone',
      recipient: '5575999999999',
      created_at: Time.zone.parse('2026-07-10 12:00:00'),
      payment_status: 'captured'
    )
    create_order(
      reference_id: 'invoice-other-date',
      recipient: '5575982479788',
      created_at: Time.zone.parse('2026-06-01 12:00:00'),
      payment_status: 'captured'
    )

    result = described_class.new(
      account: account,
      endpoint: endpoint,
      filters: {
        recipient: '(75) 98247-9788',
        payment_status: 'captured',
        date_from: '2026-07-01',
        date_to: '2026-07-31'
      }
    ).call

    expect(result).to contain_exactly(matching)
  end

  it 'never returns orders from another endpoint' do
    current = create_order(
      reference_id: 'current',
      recipient: '5575982479788',
      created_at: Time.current
    )
    foreign_delivery = create(
      :ibsoft_external_message_delivery,
      endpoint: create(:ibsoft_external_message_endpoint, account: account),
      template_type: 'order',
      order_reference_id: 'foreign',
      status: 'accepted',
      meta_message_id: 'wamid.foreign'
    )
    create(
      :ibsoft_external_message_order,
      opening_delivery: foreign_delivery,
      reference_id: 'foreign'
    )

    expect(described_class.new(account: account, endpoint: endpoint).call).to contain_exactly(current)
  end

  it 'rejects invalid date ranges' do
    expect do
      described_class.new(
        account: account,
        endpoint: endpoint,
        filters: { date_from: '2026-08-01', date_to: '2026-07-01' }
      ).call
    end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) { |error|
      expect(error.code).to eq('orders_date_range_invalid')
    }
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::Order, type: :model do
  it 'scopes the external reference by endpoint' do
    order = create(:ibsoft_external_message_order)

    duplicate = build(
      :ibsoft_external_message_order,
      endpoint: order.endpoint,
      reference_id: order.reference_id
    )

    expect(duplicate).not_to be_valid
  end

  it 'allows the same reference in another endpoint on the same channel' do
    order = create(:ibsoft_external_message_order)
    another_endpoint = create(
      :ibsoft_external_message_endpoint,
      account: order.account,
      inbox: order.inbox
    )

    another_order = build(
      :ibsoft_external_message_order,
      endpoint: another_endpoint,
      reference_id: order.reference_id
    )

    expect(another_order).to be_valid
  end

  it 'is ready after any linked delivery is accepted with a Meta ID' do
    order = create(:ibsoft_external_message_order)
    expect(order).to be_ready_for_updates

    order.opening_delivery.update!(status: 'failed', meta_message_id: nil)
    expect(order.reload).not_to be_ready_for_updates

    create(
      :ibsoft_external_message_delivery,
      endpoint: order.endpoint,
      account: order.account,
      inbox: order.inbox,
      external_order: order,
      template_type: 'order',
      order_reference_id: order.reference_id,
      status: 'accepted',
      meta_message_id: 'wamid.resend'
    )

    expect(order.reload).to be_ready_for_updates
  end

  it 'treats captured, completed, and canceled orders as final for resends' do
    order = build(:ibsoft_external_message_order)

    order.payment_status = 'captured'
    expect(order).to be_finalized_for_resend

    order.payment_status = nil
    order.order_status = 'completed'
    expect(order).to be_finalized_for_resend

    order.order_status = 'canceled'
    expect(order).to be_finalized_for_resend

    order.order_status = 'processing'
    expect(order).not_to be_finalized_for_resend
  end
end

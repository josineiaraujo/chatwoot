require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::RetentionCleanup do
  let(:endpoint) { create(:ibsoft_external_message_endpoint, retention_days: 30) }
  let(:now) { Time.zone.parse('2026-07-29 12:00:00') }
  let(:old_time) { now - 31.days }

  def old_delivery(status:)
    create(
      :ibsoft_external_message_delivery,
      endpoint: endpoint,
      status: status,
      created_at: old_time,
      received_at: old_time
    )
  end

  it 'removes expired deliveries regardless of their processing status' do
    deliveries = Ibsoft::ExternalMessaging::Delivery::STATUSES.map do |status|
      old_delivery(status: status)
    end

    result = described_class.new(endpoint: endpoint, now: now).call

    expect(result.deliveries).to eq(deliveries.size)
    expect(Ibsoft::ExternalMessaging::Delivery.where(id: deliveries.map(&:id))).to be_empty
  end

  it 'removes expired orders and updates regardless of their processing status' do
    records = Ibsoft::ExternalMessaging::OrderUpdate::STATUSES.each_with_index.map do |status, index|
      reference_id = "old-order-#{index}"
      delivery = old_delivery(status: 'accepted')
      delivery.update!(
        template_type: 'order',
        order_reference_id: reference_id,
        meta_message_id: "wamid.#{reference_id}"
      )
      order = create(
        :ibsoft_external_message_order,
        opening_delivery: delivery,
        reference_id: reference_id,
        created_at: old_time,
        updated_at: old_time
      )
      update = create(
        :ibsoft_external_message_order_update,
        order: order,
        status: status,
        created_at: old_time,
        received_at: old_time
      )

      [delivery, order, update]
    end

    result = described_class.new(endpoint: endpoint, now: now).call
    deliveries, orders, updates = records.transpose

    expect(result).to have_attributes(
      orders: orders.size,
      order_updates: updates.size,
      deliveries: deliveries.size
    )
    expect(Ibsoft::ExternalMessaging::Order.where(id: orders.map(&:id))).to be_empty
    expect(Ibsoft::ExternalMessaging::OrderUpdate.where(id: updates.map(&:id))).to be_empty
    expect(Ibsoft::ExternalMessaging::Delivery.where(id: deliveries.map(&:id))).to be_empty
  end

  it 'preserves a canonical order and its opening delivery after a recent resend' do
    opening_delivery = old_delivery(status: 'accepted')
    opening_delivery.update!(
      template_type: 'order',
      order_reference_id: 'resent-order',
      meta_message_id: 'wamid.old'
    )
    order = create(
      :ibsoft_external_message_order,
      opening_delivery: opening_delivery,
      reference_id: 'resent-order',
      created_at: old_time,
      updated_at: old_time
    )
    resend = create(
      :ibsoft_external_message_delivery,
      endpoint: endpoint,
      external_order: order,
      template_type: 'order',
      order_reference_id: order.reference_id,
      recipient: order.recipient,
      status: 'accepted',
      meta_message_id: 'wamid.recent'
    )
    order.update!(updated_at: resend.created_at)

    result = described_class.new(endpoint: endpoint, now: now).call

    expect(result).to have_attributes(orders: 0, deliveries: 0)
    expect(Ibsoft::ExternalMessaging::Order.exists?(order.id)).to be(true)
    expect(Ibsoft::ExternalMessaging::Delivery.exists?(opening_delivery.id)).to be(true)
    expect(Ibsoft::ExternalMessaging::Delivery.exists?(resend.id)).to be(true)
  end

  it 'removes an expired update while preserving its non-expired order' do
    delivery = create(:ibsoft_external_message_delivery, endpoint: endpoint, status: 'accepted')
    delivery.update!(template_type: 'order', order_reference_id: 'recent-order', meta_message_id: 'wamid.recent')
    order = create(
      :ibsoft_external_message_order,
      opening_delivery: delivery,
      reference_id: 'recent-order'
    )
    update = create(
      :ibsoft_external_message_order_update,
      order: order,
      status: 'uncertain',
      created_at: old_time,
      received_at: old_time
    )

    result = described_class.new(endpoint: endpoint, now: now).call

    expect(result).to have_attributes(orders: 0, order_updates: 1, deliveries: 0)
    expect(Ibsoft::ExternalMessaging::Order.exists?(order.id)).to be(true)
    expect(Ibsoft::ExternalMessaging::OrderUpdate.exists?(update.id)).to be(false)
    expect(Ibsoft::ExternalMessaging::Delivery.exists?(delivery.id)).to be(true)
  end

  it 'preserves all non-expired records' do
    delivery = create(:ibsoft_external_message_delivery, endpoint: endpoint, status: 'processing')
    delivery.update!(template_type: 'order', order_reference_id: 'current-order')
    order = create(
      :ibsoft_external_message_order,
      opening_delivery: delivery,
      reference_id: 'current-order'
    )
    update = create(
      :ibsoft_external_message_order_update,
      order: order,
      status: 'uncertain'
    )

    result = described_class.new(endpoint: endpoint, now: now).call

    expect(result).to have_attributes(orders: 0, order_updates: 0, deliveries: 0)
    expect(Ibsoft::ExternalMessaging::Order.exists?(order.id)).to be(true)
    expect(Ibsoft::ExternalMessaging::OrderUpdate.exists?(update.id)).to be(true)
    expect(Ibsoft::ExternalMessaging::Delivery.exists?(delivery.id)).to be(true)
  end

  it 'does not remove expired history owned by another instance' do
    foreign_endpoint = create(:ibsoft_external_message_endpoint, retention_days: 30)
    foreign_delivery = create(
      :ibsoft_external_message_delivery,
      endpoint: foreign_endpoint,
      status: 'delivered',
      created_at: old_time,
      received_at: old_time
    )

    described_class.new(endpoint: endpoint, now: now).call

    expect(Ibsoft::ExternalMessaging::Delivery.exists?(foreign_delivery.id)).to be(true)
  end
end

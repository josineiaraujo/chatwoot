require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::BulkOrderUpdateJob, type: :job do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:endpoint) { create(:ibsoft_external_message_endpoint, account: account) }

  def create_order(number)
    reference = "invoice-#{number}"
    delivery = create(
      :ibsoft_external_message_delivery,
      endpoint: endpoint,
      template_type: 'order',
      order_reference_id: reference,
      status: 'accepted',
      meta_message_id: "wamid.#{reference}"
    )
    create(
      :ibsoft_external_message_order,
      opening_delivery: delivery,
      reference_id: reference
    )
  end

  it 'creates auditable manual updates without sending synchronously' do
    orders = [create_order(1), create_order(2)]

    expect do
      described_class.perform_now(
        {
          account_id: account.id,
          endpoint_id: endpoint.id,
          requested_by_id: admin.id,
          selection: { mode: 'ids', ids: orders.map(&:id) },
          filters: {},
          attributes: { payment_status: 'captured' },
          selected_before: Time.current.iso8601(6)
        }
      )
    end.to change(Ibsoft::ExternalMessaging::OrderUpdate, :count).by(2)
       .and have_enqueued_job(Ibsoft::ExternalMessaging::SendOrderUpdateJob).exactly(2).times

    updates = Ibsoft::ExternalMessaging::OrderUpdate.where(order_id: orders.map(&:id))

    expect(updates).to all(
      have_attributes(source: 'manual', requested_by_id: admin.id, payment_status: 'captured')
    )
  end

  it 'continues large selections in bounded batches' do
    stub_const("#{described_class}::BATCH_SIZE", 2)
    orders = [create_order(1), create_order(2), create_order(3)]

    expect do
      described_class.perform_now(
        {
          account_id: account.id,
          endpoint_id: endpoint.id,
          requested_by_id: admin.id,
          selection: { mode: 'filter' },
          filters: {},
          attributes: { order_status: 'processing' },
          selected_before: Time.current.iso8601(6)
        }
      )
    end.to change(Ibsoft::ExternalMessaging::OrderUpdate, :count).by(2)
       .and have_enqueued_job(described_class).with(
         hash_including('cursor' => orders.second.id)
       )
  end

  it 'does not include orders created after the all-filter selection was confirmed' do
    selected_before = Time.zone.parse('2026-07-29 12:00:00')
    eligible_order = create_order(1)
    later_order = create_order(2)
    eligible_order.update_column(:created_at, selected_before - 1.minute) # rubocop:disable Rails/SkipsModelValidations
    later_order.update_column(:created_at, selected_before + 1.minute) # rubocop:disable Rails/SkipsModelValidations

    expect do
      described_class.perform_now(
        {
          account_id: account.id,
          endpoint_id: endpoint.id,
          requested_by_id: admin.id,
          selection: { mode: 'filter' },
          filters: {},
          attributes: { order_status: 'processing' },
          selected_before: selected_before.iso8601(6)
        }
      )
    end.to change(Ibsoft::ExternalMessaging::OrderUpdate, :count).by(1)

    expect(eligible_order.updates.reload).to be_present
    expect(later_order.updates.reload).to be_empty
  end
end

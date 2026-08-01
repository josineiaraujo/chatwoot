require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::BulkOrderUpdateScheduler do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:endpoint) { create(:ibsoft_external_message_endpoint, account: account) }
  let!(:order) do
    create(
      :ibsoft_external_message_order,
      opening_delivery: create(
        :ibsoft_external_message_delivery,
        endpoint: endpoint,
        template_type: 'order',
        order_reference_id: 'invoice-1',
        status: 'accepted',
        meta_message_id: 'wamid.invoice-1'
      ),
      reference_id: 'invoice-1'
    )
  end

  it 'queues a compact all-filter selection and reports its current size' do
    expect do
      result = described_class.new(
        account: account,
        endpoint: endpoint,
        user: admin,
        params: {
          selection: { mode: 'filter' },
          filters: { recipient: order.opening_delivery.recipient },
          update: { payment_status: 'captured' }
        }
      ).call

      expect(result.matched_count).to eq(1)
      expect(result.selection).to eq(mode: 'filter')
    end.to have_enqueued_job(Ibsoft::ExternalMessaging::BulkOrderUpdateJob)
  end

  it 'rejects empty or invalid manual updates before queueing' do
    expect do
      described_class.new(
        account: account,
        endpoint: endpoint,
        user: admin,
        params: {
          selection: { mode: 'ids', ids: [order.id] },
          update: {}
        }
      ).call
    end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) { |error|
      expect(error.code).to eq('order_update_status_required')
    }
  end

  it 'does not count an order with an uncertain update as manually updateable' do
    create(:ibsoft_external_message_order_update, order: order, status: 'uncertain')

    expect do
      described_class.new(
        account: account,
        endpoint: endpoint,
        user: admin,
        params: {
          selection: { mode: 'ids', ids: [order.id] },
          update: { payment_status: 'captured' }
        }
      ).call
    end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) { |error|
      expect(error.code).to eq('orders_selection_empty')
    }
  end
end

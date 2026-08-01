require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::DispatchPendingJob do
  it 'reenqueues a durable queued delivery' do
    delivery = create(
      :ibsoft_external_message_delivery,
      enqueued_at: 10.minutes.ago
    )

    expect do
      described_class.perform_now
    end.to have_enqueued_job(Ibsoft::ExternalMessaging::SendDeliveryJob).with(delivery.id)

    expect(delivery.reload.enqueued_at).to be_present
  end

  it 'marks abandoned processing as uncertain without resending' do
    delivery = create(
      :ibsoft_external_message_delivery,
      status: 'processing',
      processing_started_at: 20.minutes.ago
    )

    expect do
      described_class.perform_now
    end.not_to have_enqueued_job(Ibsoft::ExternalMessaging::SendDeliveryJob).with(delivery.id)

    expect(delivery.reload).to have_attributes(
      status: 'uncertain',
      error_code: 'worker_interrupted'
    )
  end

  it 'reenqueues only the first durable update for each order' do
    first = create(:ibsoft_external_message_order_update, enqueued_at: 10.minutes.ago)
    second = create(
      :ibsoft_external_message_order_update,
      order: first.order,
      enqueued_at: 10.minutes.ago
    )

    expect do
      described_class.perform_now
    end.to have_enqueued_job(Ibsoft::ExternalMessaging::SendOrderUpdateJob).with(first.id)

    queued_ids = ActiveJob::Base.queue_adapter.enqueued_jobs.filter_map do |job|
      job[:args]&.first if job[:job] == Ibsoft::ExternalMessaging::SendOrderUpdateJob
    end
    expect(queued_ids).not_to include(second.id)
  end

  it 'marks an abandoned update uncertain and keeps its order blocked' do
    update = create(
      :ibsoft_external_message_order_update,
      status: 'processing',
      processing_started_at: 20.minutes.ago
    )
    later = create(
      :ibsoft_external_message_order_update,
      order: update.order,
      enqueued_at: 10.minutes.ago
    )

    expect do
      described_class.perform_now
    end.not_to have_enqueued_job(Ibsoft::ExternalMessaging::SendOrderUpdateJob).with(later.id)

    expect(update.reload).to have_attributes(
      status: 'uncertain',
      error_code: 'worker_interrupted'
    )
  end
end

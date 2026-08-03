require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::DispatchPendingJob do
  it 'reenqueues a durable queued broadcast' do
    broadcast = create(:ibsoft_message_broadcast, status: 'queued', updated_at: 10.minutes.ago)

    expect do
      described_class.perform_now
    end.to have_enqueued_job(Ibsoft::MessageBroadcast::SendBroadcastJob).with(broadcast.id)
  end

  it 'reenqueues a queued recipient from a running bulk broadcast' do
    broadcast = create(:ibsoft_message_broadcast, status: 'running', dispatch_mode: 'bulk')
    recipient = create(
      :ibsoft_message_broadcast_recipient,
      broadcast: broadcast,
      status: 'queued',
      enqueued_at: 10.minutes.ago
    )

    expect do
      described_class.perform_now
    end.to have_enqueued_job(Ibsoft::MessageBroadcast::SendRecipientJob).with(recipient.id)

    expect(recipient.reload.enqueued_at).to be_present
  end

  it 'marks abandoned processing uncertain without resending it' do
    broadcast = create(:ibsoft_message_broadcast, status: 'running', dispatch_mode: 'bulk')
    recipient = create(
      :ibsoft_message_broadcast_recipient,
      broadcast: broadcast,
      status: 'processing',
      processing_started_at: 20.minutes.ago
    )

    expect do
      described_class.perform_now
    end.not_to have_enqueued_job(Ibsoft::MessageBroadcast::SendRecipientJob).with(recipient.id)

    expect(recipient.reload).to have_attributes(
      status: 'uncertain',
      error_code: 'worker_interrupted'
    )
    expect(broadcast.reload.status).to eq('failed')
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::BroadcastSender do
  let(:broadcast) { create(:ibsoft_message_broadcast, status: 'queued', dispatch_mode: 'bulk') }
  let!(:recipient) { create(:ibsoft_message_broadcast_recipient, broadcast: broadcast, status: 'queued') }

  before do
    allow(Ibsoft::MessageBroadcast::SendRecipientJob).to receive(:perform_later)
  end

  it 'claims a bulk broadcast and enqueues each recipient independently', :aggregate_failures do
    described_class.new(broadcast: broadcast).call

    expect(broadcast.reload).to have_attributes(status: 'running')
    expect(broadcast.started_at).to be_present
    expect(broadcast.finished_at).to be_nil
    expect(recipient.reload.enqueued_at).to be_present
    expect(Ibsoft::MessageBroadcast::SendRecipientJob).to have_received(:perform_later).with(recipient.id).once
  end

  it 'does not enqueue the same bulk broadcast twice' do
    sender = described_class.new(broadcast: broadcast)

    sender.call
    sender.call

    expect(Ibsoft::MessageBroadcast::SendRecipientJob).to have_received(:perform_later).once
  end

  it 'delivers and finalizes an individual broadcast inline', :aggregate_failures do
    broadcast.update!(dispatch_mode: 'single')
    recipient_sender = instance_double(Ibsoft::MessageBroadcast::RecipientSender)
    allow(Ibsoft::MessageBroadcast::RecipientSender).to receive(:new).and_return(recipient_sender)
    allow(recipient_sender).to receive(:call) { recipient.update!(status: 'accepted') }

    described_class.new(broadcast: broadcast).call

    expect(recipient_sender).to have_received(:call).once
    expect(broadcast.reload).to have_attributes(status: 'completed')
    expect(broadcast.finished_at).to be_present
  end

  it 'marks an individual broadcast as failed after an unexpected error' do
    broadcast.update!(dispatch_mode: 'single')
    recipient_sender = instance_double(Ibsoft::MessageBroadcast::RecipientSender)
    allow(Ibsoft::MessageBroadcast::RecipientSender).to receive(:new).and_return(recipient_sender)
    allow(recipient_sender).to receive(:call).and_raise(StandardError, 'unexpected failure')

    expect { described_class.new(broadcast: broadcast).call }.to raise_error(StandardError, 'unexpected failure')

    expect(broadcast.reload).to have_attributes(status: 'failed')
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::BroadcastSender do
  let(:broadcast) { create(:ibsoft_message_broadcast, status: 'queued') }
  let!(:recipient) { create(:ibsoft_message_broadcast_recipient, broadcast: broadcast, status: 'queued') }
  let(:recipient_sender) { instance_double(Ibsoft::MessageBroadcast::RecipientSender) }

  before do
    allow(Ibsoft::MessageBroadcast::RecipientSender).to receive(:new).and_return(recipient_sender)
  end

  it 'claims and completes a queued broadcast', :aggregate_failures do
    allow(recipient_sender).to receive(:call) { recipient.update!(status: 'sent') }

    described_class.new(broadcast: broadcast).call

    expect(broadcast.reload).to have_attributes(status: 'completed')
    expect(broadcast.started_at).to be_present
    expect(broadcast.finished_at).to be_present
    expect(recipient_sender).to have_received(:call).once
  end

  it 'does not execute the same broadcast twice', :aggregate_failures do
    allow(recipient_sender).to receive(:call) { recipient.update!(status: 'sent') }
    sender = described_class.new(broadcast: broadcast)

    sender.call
    sender.call

    expect(Ibsoft::MessageBroadcast::RecipientSender).to have_received(:new).once
    expect(recipient_sender).to have_received(:call).once
  end

  it 'marks the claimed broadcast as failed after an unexpected execution error' do
    allow(recipient_sender).to receive(:call).and_raise(StandardError, 'unexpected failure')

    expect { described_class.new(broadcast: broadcast).call }.to raise_error(StandardError, 'unexpected failure')

    expect(broadcast.reload).to have_attributes(status: 'failed')
    expect(broadcast.finished_at).to be_present
  end
end

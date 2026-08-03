require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::BroadcastFinalizer do
  let(:broadcast) { create(:ibsoft_message_broadcast, status: 'running') }

  it 'waits while at least one recipient is active' do
    create(:ibsoft_message_broadcast_recipient, broadcast: broadcast, status: 'processing')

    expect(described_class.new(broadcast: broadcast).call).to be(false)
    expect(broadcast.reload).to have_attributes(status: 'running', finished_at: nil)
  end

  it 'completes when every recipient has a successful terminal status' do
    create(:ibsoft_message_broadcast_recipient, broadcast: broadcast, status: 'accepted')
    create(:ibsoft_message_broadcast_recipient, broadcast: broadcast, status: 'skipped')

    expect(described_class.new(broadcast: broadcast).call).to be(true)
    expect(broadcast.reload).to have_attributes(status: 'completed')
    expect(broadcast.finished_at).to be_present
  end

  it 'fails when any recipient is failed or uncertain' do
    create(:ibsoft_message_broadcast_recipient, broadcast: broadcast, status: 'accepted')
    create(:ibsoft_message_broadcast_recipient, broadcast: broadcast, status: 'uncertain')

    described_class.new(broadcast: broadcast).call

    expect(broadcast.reload.status).to eq('failed')
  end

  it 'preserves the original finish time when a later webhook changes the final result' do
    recipient = create(:ibsoft_message_broadcast_recipient, broadcast: broadcast, status: 'accepted')
    described_class.new(broadcast: broadcast).call
    original_finished_at = broadcast.reload.finished_at

    travel 1.minute do
      recipient.update!(status: 'failed')
      expect(described_class.new(broadcast: broadcast).call).to be(true)
    end

    expect(broadcast.reload).to have_attributes(
      status: 'failed',
      finished_at: original_finished_at
    )
  end

  it 'does not rewrite an already finalized broadcast with the same status' do
    create(:ibsoft_message_broadcast_recipient, broadcast: broadcast, status: 'accepted')
    described_class.new(broadcast: broadcast).call

    expect(described_class.new(broadcast: broadcast.reload).call).to be(false)
  end
end

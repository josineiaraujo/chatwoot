require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::BroadcastExecutionClaim do
  let(:broadcast) { create(:ibsoft_message_broadcast, status: 'queued') }

  it 'allows only one worker to move a queued broadcast to running', :aggregate_failures do
    first_claim = described_class.new(broadcast: broadcast)
    second_claim = described_class.new(broadcast: broadcast.class.find(broadcast.id))

    expect(first_claim.acquire).to be(true)
    expect(second_claim.acquire).to be(false)
    expect(broadcast).to have_attributes(status: 'running')
    expect(broadcast.started_at).to be_present
  end

  it 'does not acquire a broadcast that is already running' do
    broadcast.update!(status: 'running', started_at: 1.minute.ago)

    expect(described_class.new(broadcast: broadcast).acquire).to be(false)
  end
end

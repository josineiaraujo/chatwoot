require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::RateLimiter do
  let(:delivery) { create(:ibsoft_external_message_delivery) }
  let(:rate_key) do
    "ibsoft:external_messaging:inbox:#{delivery.inbox_id}:rate:#{Time.current.to_i}"
  end

  it 'initializes the shared window with an atomic expiration' do
    allow(Redis::Alfred).to receive(:set).and_return('OK')
    allow(Redis::Alfred).to receive(:incr)

    expect(described_class.new(record: delivery).acquire).to be(true)
    expect(Redis::Alfred).to have_received(:set).with(
      rate_key,
      1,
      nx: true,
      ex: described_class::WINDOW_TTL
    )
    expect(Redis::Alfred).not_to have_received(:incr)
  end

  it 'increments an existing shared window and enforces the channel limit' do
    allow(Redis::Alfred).to receive(:set).and_return(nil)
    allow(Redis::Alfred).to receive(:incr)
      .with(rate_key)
      .and_return(delivery.endpoint.effective_rate_limit_per_second + 1)

    expect(described_class.new(record: delivery).acquire).to be(false)
  end
end

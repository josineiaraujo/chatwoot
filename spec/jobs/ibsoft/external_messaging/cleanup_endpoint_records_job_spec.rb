require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::CleanupEndpointRecordsJob, type: :job do
  let(:endpoint) { create(:ibsoft_external_message_endpoint) }
  let(:result) do
    Ibsoft::ExternalMessaging::RetentionCleanup::Result.new(
      orders: 1,
      order_updates: 1,
      deliveries: 1
    )
  end

  before do
    allow(Redis::Alfred).to receive(:set).and_return(true)
    allow(Redis::Alfred).to receive(:delete_if_equals)
  end

  it 'cleans one instance while holding its dedicated lock' do
    cleaner = instance_double(Ibsoft::ExternalMessaging::RetentionCleanup, call: result)
    allow(Ibsoft::ExternalMessaging::RetentionCleanup).to receive(:new).and_return(cleaner)

    described_class.perform_now(endpoint.id)

    expect(Ibsoft::ExternalMessaging::RetentionCleanup).to have_received(:new).with(endpoint: endpoint)
    expect(Redis::Alfred).to have_received(:set).with(
      "ibsoft:external_messaging:retention_cleanup:endpoint:#{endpoint.id}",
      kind_of(String),
      nx: true,
      ex: described_class::LOCK_TTL
    )
    expect(Redis::Alfred).to have_received(:delete_if_equals)
  end

  it 'does not clean when another worker owns the instance lock' do
    allow(Redis::Alfred).to receive(:set).and_return(false)
    allow(Ibsoft::ExternalMessaging::RetentionCleanup).to receive(:new)

    described_class.perform_now(endpoint.id)

    expect(Ibsoft::ExternalMessaging::RetentionCleanup).not_to have_received(:new)
  end

  it 'ignores an instance removed after the dispatcher ran' do
    allow(Ibsoft::ExternalMessaging::RetentionCleanup).to receive(:new)

    described_class.perform_now(-1)

    expect(Ibsoft::ExternalMessaging::RetentionCleanup).not_to have_received(:new)
  end
end

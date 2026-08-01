require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::CleanupExpiredRecordsJob, type: :job do
  include ActiveJob::TestHelper

  it 'uses a shared lock before scheduling every instance independently' do
    create_list(:ibsoft_external_message_endpoint, 2)
    endpoint_count = Ibsoft::ExternalMessaging::Endpoint.count
    allow(Redis::Alfred).to receive(:set).and_return(true)
    allow(Redis::Alfred).to receive(:delete_if_equals)

    expect do
      described_class.perform_now
    end.to have_enqueued_job(
      Ibsoft::ExternalMessaging::CleanupEndpointRecordsJob
    ).exactly(endpoint_count).times

    expect(Redis::Alfred).to have_received(:delete_if_equals)
  end

  it 'does nothing when another replica owns the cleanup lock' do
    create(:ibsoft_external_message_endpoint)
    allow(Redis::Alfred).to receive(:set).and_return(false)
    allow(Redis::Alfred).to receive(:delete_if_equals)

    expect do
      described_class.perform_now
    end.not_to have_enqueued_job(Ibsoft::ExternalMessaging::CleanupEndpointRecordsJob)
  end
end

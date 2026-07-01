require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::WatchdogJob, type: :job do
  it 'is queued in the scheduled jobs queue' do
    expect(described_class.queue_name).to eq('scheduled_jobs')
  end

  it 'can be enqueued' do
    expect { described_class.perform_later }.to have_enqueued_job(described_class).on_queue('scheduled_jobs')
  end

  it 'delegates execution to the watchdog runner' do
    runner_result = {
      enabled: true,
      summary: { accounts: 1, scanned: 1, assigned: 1, skipped: 0, by_reason: {} }
    }
    runner = instance_double(Ibsoft::ConversationDistribution::WatchdogRunner, perform: runner_result)

    expect(Ibsoft::ConversationDistribution::WatchdogRunner).to receive(:new).with(
      account_id: 1,
      inbox_id: 2,
      team_id: 3,
      limit: 4
    ).and_return(runner)

    expect(described_class.perform_now(account_id: 1, inbox_id: 2, team_id: 3, limit: 4)).to eq(runner_result)
  end
end

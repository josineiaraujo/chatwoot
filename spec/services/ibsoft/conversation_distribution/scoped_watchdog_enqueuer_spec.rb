require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::ScopedWatchdogEnqueuer do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, team: team) }

  it 'enqueues a watchdog run scoped to the affected queue' do
    expect { described_class.new(conversation: conversation, team: team).perform }
      .to have_enqueued_job(Ibsoft::ConversationDistribution::WatchdogJob).with(
        account_id: account.id,
        inbox_id: inbox.id,
        team_id: team.id
      )
  end

  it 'reports an infrastructure failure without raising after the database operation' do
    allow(Ibsoft::ConversationDistribution::WatchdogJob).to receive(:perform_later).and_raise(Redis::BaseError)

    result = described_class.new(conversation: conversation, team: team).perform

    expect(result).to eq(enqueued: false, error: 'Redis::BaseError')
  end
end

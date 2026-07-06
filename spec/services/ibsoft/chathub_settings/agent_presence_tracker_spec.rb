require 'rails_helper'

RSpec.describe Ibsoft::ChathubSettings::AgentPresenceTracker do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }

  it 'records offline and online transitions from the online tracker snapshot' do
    agent
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return({})

    described_class.sync_account!(account)

    state = Ibsoft::ChathubSettings::AgentPresenceState.find_by!(account: account, user: agent)
    expect(state.current_status).to eq('offline')
    expect(state.last_offline_at).to be_present

    travel 2.minutes do
      allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
      described_class.sync_account!(account)
    end

    state.reload
    expect(state.current_status).to eq('online')
    expect(state.last_online_at).to be_present
  end
end

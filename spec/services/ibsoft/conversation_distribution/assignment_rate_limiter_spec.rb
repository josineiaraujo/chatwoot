require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AssignmentRateLimiter do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, team: team) }
  let(:policy) do
    {
      config: {
        'distribution' => {
          'fair_distribution_limit' => 2,
          'fair_distribution_window' => 3600
        }
      }
    }
  end
  let(:limiter) { described_class.new(account: account, conversation: conversation, agent: agent, policy: policy) }
  let(:assignment_key) do
    format(
      described_class::KEY,
      account_id: account.id,
      inbox_id: inbox.id,
      team_id: team.id,
      agent_id: agent.id
    )
  end
  let(:now) { Time.zone.local(2026, 7, 3, 12, 0, 0) }

  before do
    allow(Time).to receive(:current).and_return(now)
  end

  describe '#track_assignment' do
    it 'stores the assignment in a rolling sorted set without scanning Redis keys' do
      expect(Redis::Alfred).to receive(:zremrangebyscore).with(assignment_key, '-inf', now.to_i - 3600)
      expect(Redis::Alfred).to receive(:zadd).with(assignment_key, now.to_i, conversation.id)
      expect(Redis::Alfred).to receive(:expire).with(assignment_key, 3600)
      expect(Redis::Alfred).not_to receive(:keys_count)

      limiter.track_assignment
    end
  end

  describe '#current_count' do
    it 'counts active assignments through the sorted set cardinality' do
      expect(Redis::Alfred).to receive(:zremrangebyscore).with(assignment_key, '-inf', now.to_i - 3600)
      expect(Redis::Alfred).to receive(:zcard).with(assignment_key).and_return(2)
      expect(Redis::Alfred).not_to receive(:keys_count)

      expect(limiter.current_count).to eq(2)
    end
  end

  describe '#within_limit?' do
    it 'returns true immediately below the configured rolling window limit' do
      allow(Redis::Alfred).to receive(:zremrangebyscore)
      allow(Redis::Alfred).to receive(:zcard).with(assignment_key).and_return(1)

      expect(limiter.within_limit?).to be(true)
    end

    it 'returns false when the rolling window count reaches the configured limit' do
      allow(Redis::Alfred).to receive(:zremrangebyscore)
      allow(Redis::Alfred).to receive(:zcard).with(assignment_key).and_return(2)

      expect(limiter.within_limit?).to be(false)
    end

    it 'uses safe defaults when limit and window are invalid' do
      policy[:config]['distribution']['fair_distribution_limit'] = 0
      policy[:config]['distribution']['fair_distribution_window'] = 0
      expect(Redis::Alfred).to receive(:zremrangebyscore).with(assignment_key, '-inf', now.to_i - 3600)
      expect(Redis::Alfred).to receive(:zcard).with(assignment_key).and_return(99)

      expect(limiter.within_limit?).to be(true)
    end
  end

  it 'uses a separate key when the conversation has no team' do
    conversation.update!(team: nil)
    key_without_team = format(
      described_class::KEY,
      account_id: account.id,
      inbox_id: inbox.id,
      team_id: 'none',
      agent_id: agent.id
    )
    expect(Redis::Alfred).to receive(:zremrangebyscore).with(key_without_team, '-inf', now.to_i - 3600)
    expect(Redis::Alfred).to receive(:zcard).with(key_without_team).and_return(0)

    expect(limiter.current_count).to eq(0)
  end
end

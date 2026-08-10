require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::CandidateEvaluator do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:conversation) do
    create(:conversation, account: account, team: team, waiting_since: 10.minutes.ago)
  end
  let(:policy) do
    {
      enabled: true,
      config: { 'eligible_sources' => ['manual_team_transfer'] }
    }
  end
  let(:source) { { source: 'manual_team_transfer' } }

  it 'accepts a genuinely unassigned human-distribution candidate' do
    result = described_class.new(conversation: conversation, policy: policy, source: source).perform

    expect(result).to eq(eligible: true, reasons: [])
  end

  it 'rejects a conversation still owned by an AgentBot' do
    conversation.update!(assignee_agent_bot: create(:agent_bot, account: account))

    result = described_class.new(conversation: conversation, policy: policy, source: source).perform

    expect(result[:eligible]).to be(false)
    expect(result[:reasons]).to include('agent_bot_assignee_present')
  end
end

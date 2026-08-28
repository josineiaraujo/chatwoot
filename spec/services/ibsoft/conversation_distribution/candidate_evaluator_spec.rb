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

  it 'rejects a conversation that is not open' do
    conversation.update!(status: :resolved)

    expect(result[:reasons]).to include('not_open')
  end

  it 'rejects a conversation assigned to a human agent' do
    conversation.update!(assignee: create(:user, account: account))

    expect(result[:reasons]).to include('human_assignee_present')
  end

  it 'rejects a conversation without a team' do
    conversation.update!(team: nil)

    expect(result[:reasons]).to include('missing_team')
  end

  it 'rejects a conversation after the first human reply' do
    conversation.update!(first_reply_created_at: 1.minute.ago)

    expect(result[:reasons]).to include('first_human_reply_present')
  end

  it 'accepts a queue return even when a previous first reply exists' do
    conversation.update!(first_reply_created_at: 1.minute.ago)
    Ibsoft::ConversationDistribution::SourceMarker.new(
      conversation: conversation,
      source: 'manual_team_transfer',
      reason: Ibsoft::ConversationDistribution::QueueReturnMarker::REASON
    ).perform

    expect(result).to eq(eligible: true, reasons: [])
  end

  it 'rejects a conversation without a waiting timestamp' do
    conversation.update!(waiting_since: nil)

    expect(result[:reasons]).to include('missing_waiting_since')
  end

  it 'rejects a conversation when the effective policy is disabled' do
    policy[:enabled] = false

    expect(result[:reasons]).to include('policy_disabled')
  end

  it 'rejects a conversation when the source marker is missing' do
    source[:source] = nil

    expect(result[:reasons]).to include('missing_source')
  end

  it 'rejects a source that is not allowed by the policy' do
    source[:source] = 'agent_initiated'

    expect(result[:reasons]).to include('source_not_allowed')
  end

  it 'accepts every source explicitly selected in a custom source combination' do
    policy[:config]['eligible_sources'] = %w[manual_team_transfer bot_team_transfer queue_return]

    %w[manual_team_transfer bot_team_transfer queue_return].each do |eligible_source|
      source[:source] = eligible_source

      expect(result).to eq(eligible: true, reasons: [])
    end
  end

  it 'rejects all sources when the eligible source list is empty' do
    policy[:config]['eligible_sources'] = []

    expect(result[:reasons]).to include('source_not_allowed')
  end

  it 'reports every applicable rejection reason in a single evaluation' do
    conversation.update!(status: :resolved, team: nil, waiting_since: nil, first_reply_created_at: 1.minute.ago)
    conversation.update!(assignee: create(:user, account: account))
    policy[:enabled] = false
    source[:source] = 'agent_initiated'

    expect(result).to eq(
      eligible: false,
      reasons: %w[
        not_open
        human_assignee_present
        missing_team
        first_human_reply_present
        missing_waiting_since
        policy_disabled
        source_not_allowed
      ]
    )
  end

  def result
    described_class.new(conversation: conversation, policy: policy, source: source).perform
  end
end

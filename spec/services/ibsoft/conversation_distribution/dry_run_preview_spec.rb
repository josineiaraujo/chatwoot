require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::DryRunPreview do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }

  it 'marks a bot handoff conversation as eligible when the effective policy is enabled' do
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
    conversation = create(:conversation, account: account, inbox: inbox, team: team, waiting_since: 10.minutes.ago)
    create(
      :reporting_event,
      account: account,
      inbox: inbox,
      conversation: conversation,
      name: 'conversation_bot_handoff'
    )

    preview = described_class.new(account: account).perform
    candidate = preview[:candidates].first

    expect(preview[:summary]).to include(eligible: 1, ineligible: 0, scanned: 1)
    expect(candidate).to include(
      conversation_id: conversation.id,
      source: 'bot_handoff',
      source_confidence: 'reporting_event',
      eligible: true,
      reasons: []
    )
  end

  it 'keeps candidates ineligible when the policy is disabled' do
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: false)
    conversation = create(:conversation, account: account, inbox: inbox, team: team, waiting_since: 10.minutes.ago)

    preview = described_class.new(account: account).perform
    candidate = preview[:candidates].first

    expect(candidate).to include(
      conversation_id: conversation.id,
      source: 'manual_team_transfer',
      source_confidence: 'inferred_team_queue',
      eligible: false,
      reasons: include('policy_disabled')
    )
  end

  it 'accepts explicit system transfers when the policy allows the source' do
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
    conversation = create(:conversation, account: account, inbox: inbox, team: team, waiting_since: 10.minutes.ago)
    Ibsoft::ConversationDistribution::SourceMarker.new(
      conversation: conversation,
      source: 'system_team_transfer'
    ).perform

    preview = described_class.new(account: account).perform
    candidate = preview[:candidates].first

    expect(candidate).to include(
      conversation_id: conversation.id,
      source: 'system_team_transfer',
      source_confidence: 'explicit',
      eligible: true,
      reasons: []
    )
  end

  it 'rejects candidates when their source is not allowed by the effective policy' do
    create(
      :ibsoft_distribution_channel_policy,
      account: account,
      inbox: inbox,
      enabled: true,
      config: { eligible_sources: ['bot_handoff'] }
    )
    conversation = create(:conversation, account: account, inbox: inbox, team: team, waiting_since: 10.minutes.ago)
    Ibsoft::ConversationDistribution::SourceMarker.new(
      conversation: conversation,
      source: 'manual_team_transfer'
    ).perform

    preview = described_class.new(account: account).perform
    candidate = preview[:candidates].first

    expect(candidate).to include(
      conversation_id: conversation.id,
      source: 'manual_team_transfer',
      source_confidence: 'explicit',
      eligible: false,
      reasons: include('source_not_allowed')
    )
  end

  it 'uses team override policy before channel policy' do
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: false)
    create(
      :ibsoft_distribution_team_policy,
      account: account,
      team: team,
      enabled: true,
      override_channel_policy: true
    )
    create(:conversation, account: account, inbox: inbox, team: team, waiting_since: 10.minutes.ago)

    preview = described_class.new(account: account).perform
    candidate = preview[:candidates].first

    expect(candidate[:eligible]).to be(true)
    expect(candidate[:policy]).to include(source: 'team', policy_type: 'team', enabled: true)
  end

  it 'uses disabled team override before enabled channel policy' do
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
    create(
      :ibsoft_distribution_team_policy,
      account: account,
      team: team,
      enabled: false,
      override_channel_policy: true
    )
    create(:conversation, account: account, inbox: inbox, team: team, waiting_since: 10.minutes.ago)

    preview = described_class.new(account: account).perform
    candidate = preview[:candidates].first

    expect(candidate[:eligible]).to be(false)
    expect(candidate[:reasons]).to include('policy_disabled')
    expect(candidate[:policy]).to include(source: 'team', policy_type: 'team', enabled: false)
  end
end

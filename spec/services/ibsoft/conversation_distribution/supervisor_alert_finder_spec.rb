require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::SupervisorAlertFinder do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }

  it 'returns waiting unassigned conversations after the configured threshold' do
    create(
      :ibsoft_distribution_channel_policy,
      account: account,
      inbox: inbox,
      enabled: true,
      config: { supervisor_alert: { enabled: true, threshold_minutes: 5 } }
    )
    conversation = create(:conversation, account: account, inbox: inbox, team: team)
    conversation.update!(waiting_since: 10.minutes.ago)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, alerts: 1)
    expect(result.dig(:summary, :by_reason)).to include('unassigned_waiting' => 1)
    expect(result[:alerts].first).to include(
      conversation_id: conversation.id,
      display_id: conversation.display_id,
      reason: 'unassigned_waiting',
      threshold_minutes: 5,
      severity: 'critical'
    )
  end

  it 'marks alerts as warning before the critical threshold' do
    create(
      :ibsoft_distribution_channel_policy,
      account: account,
      inbox: inbox,
      enabled: true,
      config: { supervisor_alert: { enabled: true, threshold_minutes: 10 } }
    )
    conversation = create(:conversation, account: account, inbox: inbox, team: team)
    conversation.update!(waiting_since: 12.minutes.ago)

    result = described_class.new(account: account).perform

    expect(result.dig(:alerts, 0)).to include(
      conversation_id: conversation.id,
      severity: 'warning'
    )
    expect(result.dig(:summary, :by_severity)).to include('warning' => 1)
  end

  it 'does not return conversations before the configured threshold' do
    create(
      :ibsoft_distribution_channel_policy,
      account: account,
      inbox: inbox,
      enabled: true,
      config: { supervisor_alert: { enabled: true, threshold_minutes: 30 } }
    )
    conversation = create(:conversation, account: account, inbox: inbox, team: team)
    conversation.update!(waiting_since: 10.minutes.ago)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, alerts: 0)
    expect(result[:alerts]).to be_empty
  end

  it 'does not return conversations when supervisor alerts are disabled' do
    create(
      :ibsoft_distribution_channel_policy,
      account: account,
      inbox: inbox,
      enabled: true,
      config: { supervisor_alert: { enabled: false, threshold_minutes: 5 } }
    )
    conversation = create(:conversation, account: account, inbox: inbox, team: team)
    conversation.update!(waiting_since: 10.minutes.ago)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, alerts: 0)
    expect(result[:alerts]).to be_empty
  end

  it 'uses team policy override before channel policy' do
    create(
      :ibsoft_distribution_channel_policy,
      account: account,
      inbox: inbox,
      enabled: true,
      config: { supervisor_alert: { enabled: false, threshold_minutes: 5 } }
    )
    create(
      :ibsoft_distribution_team_policy,
      account: account,
      inbox: inbox,
      team: team,
      enabled: true,
      override_channel_policy: true,
      config: { supervisor_alert: { enabled: true, threshold_minutes: 5 } }
    )
    conversation = create(:conversation, account: account, inbox: inbox, team: team)
    conversation.update!(waiting_since: 10.minutes.ago)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, alerts: 1)
    expect(result.dig(:alerts, 0, :policy)).to include(source: 'team', policy_type: 'team')
  end
end

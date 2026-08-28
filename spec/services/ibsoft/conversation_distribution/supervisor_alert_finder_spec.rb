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

  it 'loads the latest distribution events for all alert candidates in one query' do
    create(
      :ibsoft_distribution_channel_policy,
      account: account,
      inbox: inbox,
      enabled: true,
      config: { supervisor_alert: { enabled: true, threshold_minutes: 5 } }
    )
    first_conversation = create(:conversation, account: account, inbox: inbox, team: team)
    second_conversation = create(:conversation, account: account, inbox: inbox, team: team)
    first_conversation.update!(waiting_since: 10.minutes.ago)
    second_conversation.update!(waiting_since: 10.minutes.ago)
    create(
      :ibsoft_distribution_event_log,
      account: account,
      inbox: inbox,
      team: team,
      conversation: first_conversation,
      created_at: 3.minutes.ago
    )
    latest_first_event = create(
      :ibsoft_distribution_event_log,
      account: account,
      inbox: inbox,
      team: team,
      conversation: first_conversation,
      created_at: 2.minutes.ago
    )
    latest_second_event = create(
      :ibsoft_distribution_event_log,
      account: account,
      inbox: inbox,
      team: team,
      conversation: second_conversation,
      created_at: 1.minute.ago
    )
    event_queries = []

    subscriber = lambda do |_name, _started, _finished, _unique_id, data|
      event_queries << data[:sql] if data[:sql].include?('SELECT DISTINCT ON') &&
                                     data[:sql].include?('ibsoft_conversation_distribution_event_logs')
    end

    result = ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
      described_class.new(account: account).perform
    end

    events_by_conversation = result[:alerts].index_by { |alert| alert[:conversation_id] }
    expect(events_by_conversation.dig(first_conversation.id, :last_distribution_event, :id)).to eq(latest_first_event.id)
    expect(events_by_conversation.dig(second_conversation.id, :last_distribution_event, :id)).to eq(latest_second_event.id)
    expect(event_queries.size).to eq(1)
  end
end

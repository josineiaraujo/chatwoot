require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AgentStabilizationFilter do
  let(:account) { create(:account) }
  let(:first_agent) { create(:user, account: account) }
  let(:second_agent) { create(:user, account: account) }
  let(:allowed_agent_ids) { [first_agent.id, second_agent.id] }

  before do
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return({})
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(
      first_agent.id.to_s => 'online'
    )
  end

  it 'does not filter agents when stabilization is disabled' do
    create_setting(enabled: false)

    expect(result).to eq(allowed_agent_ids)
  end

  it 'keeps an agent who recently returned after the configured offline threshold' do
    create_setting(max_assignments_during_window: 2)
    create_presence(first_agent, last_online_at: 2.minutes.ago, last_offline_at: 2.hours.ago)

    expect(result).to contain_exactly(first_agent.id, second_agent.id)
  end

  it 'filters a stabilizing agent after reaching the assignment limit' do
    create_setting(max_assignments_during_window: 2)
    state = create_presence(first_agent, last_online_at: 2.minutes.ago, last_offline_at: 2.hours.ago)
    create_completed_events(first_agent, state.last_online_at, count: 2)

    expect(result).to eq([second_agent.id])
  end

  it 'counts assignment, redistribution and manual claim completion events' do
    create_setting(max_assignments_during_window: 3)
    state = create_presence(first_agent, last_online_at: 2.minutes.ago, last_offline_at: 2.hours.ago)
    %w[assignment_completed redistribution_completed agent_claim_completed].each_with_index do |event_type, index|
      create(
        :ibsoft_distribution_event_log,
        account: account,
        new_assignee: first_agent,
        event_type: event_type,
        created_at: state.last_online_at + (index + 1).seconds
      )
    end

    expect(result).to eq([second_agent.id])
  end

  it 'ignores failed and skipped events when calculating the stabilization limit' do
    create_setting(max_assignments_during_window: 1)
    state = create_presence(first_agent, last_online_at: 2.minutes.ago, last_offline_at: 2.hours.ago)
    create(
      :ibsoft_distribution_event_log,
      account: account,
      new_assignee: first_agent,
      event_type: 'assignment_skipped',
      created_at: state.last_online_at + 1.second
    )

    expect(result).to contain_exactly(first_agent.id, second_agent.id)
  end

  it 'ignores completed events from before the current login' do
    create_setting(max_assignments_during_window: 1)
    state = create_presence(first_agent, last_online_at: 2.minutes.ago, last_offline_at: 2.hours.ago)
    create_completed_events(first_agent, state.last_online_at - 1.minute, count: 1)

    expect(result).to contain_exactly(first_agent.id, second_agent.id)
  end

  it 'does not stabilize an agent whose offline period was shorter than the threshold' do
    create_setting(offline_threshold_minutes: 60, max_assignments_during_window: 1)
    state = create_presence(first_agent, last_online_at: 2.minutes.ago, last_offline_at: 30.minutes.ago)
    create_completed_events(first_agent, state.last_online_at, count: 1)

    expect(result).to contain_exactly(first_agent.id, second_agent.id)
  end

  it 'does not stabilize an agent after the configured window expires' do
    create_setting(window_minutes: 10, max_assignments_during_window: 1)
    state = create_presence(first_agent, last_online_at: 11.minutes.ago, last_offline_at: 2.hours.ago)
    create_completed_events(first_agent, state.last_online_at, count: 1)

    expect(result).to contain_exactly(first_agent.id, second_agent.id)
  end

  it 'disables stabilization when the minimum number of allowed agents is online' do
    create_setting(minimum_online_agents_to_disable: 2, max_assignments_during_window: 1)
    state = create_presence(first_agent, last_online_at: 2.minutes.ago, last_offline_at: 2.hours.ago)
    create_completed_events(first_agent, state.last_online_at, count: 1)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(
      first_agent.id.to_s => 'online',
      second_agent.id.to_s => 'online'
    )

    expect(result).to eq(allowed_agent_ids)
  end

  it 'does not count online users outside the allowed candidate list' do
    third_agent = create(:user, account: account)
    create_setting(minimum_online_agents_to_disable: 2, max_assignments_during_window: 1)
    state = create_presence(first_agent, last_online_at: 2.minutes.ago, last_offline_at: 2.hours.ago)
    create_completed_events(first_agent, state.last_online_at, count: 1)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(
      first_agent.id.to_s => 'online',
      third_agent.id.to_s => 'online'
    )

    expect(result).to eq([second_agent.id])
  end

  it 'isolates presence states and events by account' do
    other_account = create(:account)
    create_setting(max_assignments_during_window: 1)
    state = create_presence(first_agent, last_online_at: 2.minutes.ago, last_offline_at: 2.hours.ago)
    create(
      :ibsoft_distribution_event_log,
      account: other_account,
      new_assignee: first_agent,
      event_type: 'assignment_completed',
      created_at: state.last_online_at + 1.second
    )

    expect(result).to contain_exactly(first_agent.id, second_agent.id)
  end

  def result
    described_class.new(account: account, allowed_agent_ids: allowed_agent_ids).perform
  end

  def create_setting(overrides = {})
    config = {
      enabled: true,
      offline_threshold_minutes: 60,
      window_minutes: 10,
      max_assignments_during_window: 1,
      minimum_online_agents_to_disable: 2
    }.merge(overrides)
    create(:ibsoft_chathub_account_setting, account: account, config: { login_stabilization: config })
  end

  def create_presence(agent, last_online_at:, last_offline_at:)
    create(
      :ibsoft_chathub_agent_presence_state,
      account: account,
      user: agent,
      current_status: 'online',
      last_online_at: last_online_at,
      last_offline_at: last_offline_at
    )
  end

  def create_completed_events(agent, start_at, count:)
    count.times do |index|
      create(
        :ibsoft_distribution_event_log,
        account: account,
        new_assignee: agent,
        event_type: 'assignment_completed',
        created_at: start_at + (index + 1).seconds
      )
    end
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::WatchdogRunner do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:other_account) { create(:account) }
  let(:executor_result) do
    {
      real_assignment_enabled: true,
      filters: { inbox_id: nil, team_id: nil },
      summary: { scanned: 2, assigned: 1, skipped: 1, by_reason: { 'assigned_to_agent' => 1, 'no_available_agent' => 1 } }
    }
  end
  let(:redistribution_result) do
    {
      real_assignment_enabled: true,
      filters: { inbox_id: nil, team_id: nil },
      summary: { scanned: 1, redistributed: 1, skipped: 0, ignored: 0, by_reason: { 'first_response_timeout' => 1 } }
    }
  end
  let(:automation_handoff_result) do
    {
      real_assignment_enabled: true,
      filters: { inbox_id: nil },
      summary: { scanned: 1, handoffed: 1, skipped: 0, ignored: 0, by_reason: { 'automation_stalled' => 1 } }
    }
  end

  before do
    Ibsoft::ConversationDistribution::ChannelPolicy.delete_all
    Ibsoft::ConversationDistribution::TeamPolicy.delete_all
    allow(SecureRandom).to receive(:uuid).and_return('watchdog-token')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:watchdog_lock_ttl).and_return(300)
    allow(Redis::Alfred).to receive(:set).and_return(true)
    allow(Redis::Alfred).to receive(:delete_if_equals).and_return(true)
  end

  it 'does not scan accounts when the watchdog job flag is disabled' do
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:job_enabled?).and_return(false)

    expect(Ibsoft::ConversationDistribution::AutomationHandoffExecutor).not_to receive(:new)
    expect(Ibsoft::ConversationDistribution::AssignmentExecutor).not_to receive(:new)
    expect(Ibsoft::ConversationDistribution::RedistributionExecutor).not_to receive(:new)

    result = described_class.new.perform

    expect(result).to include(enabled: false)
    expect(result[:summary]).to include(accounts: 0, scanned: 0, handoffed: 0, assigned: 0, redistributed: 0, skipped: 0)
  end

  it 'skips the round when another watchdog execution is still running' do
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:job_enabled?).and_return(true)
    allow(Redis::Alfred).to receive(:set).and_return(false)

    expect(Ibsoft::ConversationDistribution::AutomationHandoffExecutor).not_to receive(:new)
    expect(Ibsoft::ConversationDistribution::AssignmentExecutor).not_to receive(:new)
    expect(Ibsoft::ConversationDistribution::RedistributionExecutor).not_to receive(:new)

    result = described_class.new.perform

    expect(result).to include(enabled: true, locked: true, limit: 50)
    expect(result[:summary]).to include(accounts: 0, scanned: 0, handoffed: 0, assigned: 0, redistributed: 0, skipped: 0)
  end

  it 'runs only accounts with active Ibsoft distribution policies', :aggregate_failures do
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
    create(:ibsoft_distribution_channel_policy, account: other_account, enabled: false)
    automation_handoff_executor = instance_double(
      Ibsoft::ConversationDistribution::AutomationHandoffExecutor,
      perform: automation_handoff_result
    )
    executor = instance_double(Ibsoft::ConversationDistribution::AssignmentExecutor, perform: executor_result)
    redistribution_executor = instance_double(Ibsoft::ConversationDistribution::RedistributionExecutor, perform: redistribution_result)

    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:job_enabled?).and_return(true)
    allow(Ibsoft::ConversationDistribution::AutomationHandoffExecutor).to receive(:new).with(
      account: account,
      inbox_id: nil,
      limit: 25
    ).and_return(automation_handoff_executor)
    allow(Ibsoft::ConversationDistribution::AssignmentExecutor).to receive(:new).with(
      account: account,
      inbox_id: nil,
      team_id: nil,
      limit: 25
    ).and_return(executor)
    allow(Ibsoft::ConversationDistribution::RedistributionExecutor).to receive(:new).with(
      account: account,
      inbox_id: nil,
      team_id: nil,
      limit: 25
    ).and_return(redistribution_executor)

    result = described_class.new(limit: 25).perform

    expect(Ibsoft::ConversationDistribution::AutomationHandoffExecutor).to have_received(:new).once
    expect(Ibsoft::ConversationDistribution::AssignmentExecutor).to have_received(:new).once
    expect(Ibsoft::ConversationDistribution::RedistributionExecutor).to have_received(:new).once
    expect(result).to include(enabled: true, limit: 25)
    expect(result[:summary]).to include(accounts: 1, scanned: 4, handoffed: 1, assigned: 1, redistributed: 1, skipped: 1)
    expect(result[:summary][:by_reason]).to include('assigned_to_agent' => 1, 'no_available_agent' => 1)
    expect(result[:summary][:by_reason]).to include('first_response_timeout' => 1)
    expect(result[:summary][:by_reason]).to include('automation_stalled' => 1)
  end

  it 'runs accounts with active automation handoff policies even without distribution links' do
    target_team = create(:team, account: account)
    create(:ibsoft_automation_handoff_policy, account: account, inbox: inbox, target_team: target_team, enabled: true)
    automation_handoff_executor = instance_double(
      Ibsoft::ConversationDistribution::AutomationHandoffExecutor,
      perform: automation_handoff_result
    )
    executor = instance_double(Ibsoft::ConversationDistribution::AssignmentExecutor, perform: executor_result)
    redistribution_executor = instance_double(Ibsoft::ConversationDistribution::RedistributionExecutor, perform: redistribution_result)

    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:job_enabled?).and_return(true)
    allow(Ibsoft::ConversationDistribution::AutomationHandoffExecutor).to receive(:new).and_return(automation_handoff_executor)
    allow(Ibsoft::ConversationDistribution::AssignmentExecutor).to receive(:new).and_return(executor)
    allow(Ibsoft::ConversationDistribution::RedistributionExecutor).to receive(:new).and_return(redistribution_executor)

    result = described_class.new(limit: 25).perform

    expect(Ibsoft::ConversationDistribution::AutomationHandoffExecutor).to have_received(:new).once
    expect(result[:summary]).to include(accounts: 1, handoffed: 1)
  end

  it 'does not sync account presence when login stabilization is disabled' do
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
    automation_handoff_executor = instance_double(
      Ibsoft::ConversationDistribution::AutomationHandoffExecutor,
      perform: automation_handoff_result
    )
    executor = instance_double(Ibsoft::ConversationDistribution::AssignmentExecutor, perform: executor_result)
    redistribution_executor = instance_double(Ibsoft::ConversationDistribution::RedistributionExecutor, perform: redistribution_result)

    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:job_enabled?).and_return(true)
    allow(Ibsoft::ConversationDistribution::AutomationHandoffExecutor).to receive(:new).and_return(automation_handoff_executor)
    allow(Ibsoft::ConversationDistribution::AssignmentExecutor).to receive(:new).and_return(executor)
    allow(Ibsoft::ConversationDistribution::RedistributionExecutor).to receive(:new).and_return(redistribution_executor)

    expect(Ibsoft::ChathubSettings::AgentPresenceTracker).not_to receive(:sync_account!)

    described_class.new.perform
  end

  it 'syncs account presence when login stabilization is enabled' do
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
    create(:ibsoft_chathub_account_setting, account: account, config: { login_stabilization: { enabled: true } })
    automation_handoff_executor = instance_double(
      Ibsoft::ConversationDistribution::AutomationHandoffExecutor,
      perform: automation_handoff_result
    )
    executor = instance_double(Ibsoft::ConversationDistribution::AssignmentExecutor, perform: executor_result)
    redistribution_executor = instance_double(Ibsoft::ConversationDistribution::RedistributionExecutor, perform: redistribution_result)

    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:job_enabled?).and_return(true)
    allow(Ibsoft::ConversationDistribution::AutomationHandoffExecutor).to receive(:new).and_return(automation_handoff_executor)
    allow(Ibsoft::ConversationDistribution::AssignmentExecutor).to receive(:new).and_return(executor)
    allow(Ibsoft::ConversationDistribution::RedistributionExecutor).to receive(:new).and_return(redistribution_executor)

    expect(Ibsoft::ChathubSettings::AgentPresenceTracker).to receive(:sync_account!).with(account)

    described_class.new.perform
  end

  it 'allows a specific account run even before that account has an active policy' do
    other_inbox = create(:inbox, account: other_account)
    automation_handoff_executor = instance_double(
      Ibsoft::ConversationDistribution::AutomationHandoffExecutor,
      perform: automation_handoff_result
    )
    executor = instance_double(Ibsoft::ConversationDistribution::AssignmentExecutor, perform: executor_result)
    redistribution_executor = instance_double(Ibsoft::ConversationDistribution::RedistributionExecutor, perform: redistribution_result)

    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:job_enabled?).and_return(true)
    allow(Ibsoft::ConversationDistribution::AutomationHandoffExecutor).to receive(:new).with(
      account: other_account,
      inbox_id: other_inbox.id,
      limit: 10
    ).and_return(automation_handoff_executor)
    allow(Ibsoft::ConversationDistribution::AssignmentExecutor).to receive(:new).with(
      account: other_account,
      inbox_id: other_inbox.id,
      team_id: nil,
      limit: 10
    ).and_return(executor)
    allow(Ibsoft::ConversationDistribution::RedistributionExecutor).to receive(:new).with(
      account: other_account,
      inbox_id: other_inbox.id,
      team_id: nil,
      limit: 10
    ).and_return(redistribution_executor)

    result = described_class.new(account_id: other_account.id, inbox_id: other_inbox.id, limit: 10).perform

    expect(Ibsoft::ConversationDistribution::AutomationHandoffExecutor).to have_received(:new).once
    expect(Ibsoft::ConversationDistribution::AssignmentExecutor).to have_received(:new).once
    expect(Ibsoft::ConversationDistribution::RedistributionExecutor).to have_received(:new).once
    expect(result[:summary]).to include(accounts: 1, scanned: 4, handoffed: 1, assigned: 1, redistributed: 1, skipped: 1)
  end
end

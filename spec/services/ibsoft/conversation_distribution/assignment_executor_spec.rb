require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AssignmentExecutor do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:agent) { create(:user, account: account, auto_offline: false) }
  let(:secondary_agent) { create(:user, account: account, auto_offline: false) }
  let(:conversation) do
    create(
      :conversation,
      account: account,
      inbox: inbox,
      team: team,
      waiting_since: 10.minutes.ago
    )
  end

  before do
    account.disable_features!('assignment_v2')
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
    Ibsoft::ConversationDistribution::SourceMarker.new(
      conversation: conversation,
      source: 'manual_team_transfer'
    ).perform
  end

  it 'keeps the native Assignment V2 worker inactive for the account' do
    allow(Account).to receive(:find_in_batches).and_yield([account])

    expect(account.reload.feature_enabled?('assignment_v2')).to be(false)
    expect(inbox.reload.auto_assignment_v2_enabled?).to be(false)
    expect(AutoAssignment::AssignmentJob).not_to receive(:enqueue_for_inbox)

    AutoAssignment::PeriodicAssignmentJob.new.perform
  end

  it 'does not assign conversations when real assignment is disabled' do
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(false)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 0, skipped: 1)
    expect(conversation.reload.assignee).to be_nil

    event = Ibsoft::ConversationDistribution::EventLog.last
    expect(event).to have_attributes(
      conversation_id: conversation.id,
      event_type: 'assignment_skipped',
      reason: 'real_assignment_disabled'
    )
  end

  it 'does not create duplicate skipped logs for the same conversation and reason inside the dedupe window' do
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(false)

    expect { described_class.new(account: account).perform }.to change(Ibsoft::ConversationDistribution::EventLog, :count).by(1)
    expect { described_class.new(account: account).perform }.not_to change(Ibsoft::ConversationDistribution::EventLog, :count)
  end

  it 'assigns an eligible conversation to an online team agent when real assignment is enabled' do
    account.update!(locale: 'pt_BR')
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = nil
    perform_enqueued_jobs(only: Conversations::ActivityMessageJob) do
      result = described_class.new(account: account).perform
    end

    expect(result[:summary]).to include(scanned: 1, assigned: 1, skipped: 0)
    expect(conversation.reload.assignee).to eq(agent)
    activity_content = "Atendimento atribuído automaticamente para #{agent.name} pela distribuição automática."
    expect(conversation.messages.activity.where(content: activity_content)).to exist

    event = Ibsoft::ConversationDistribution::EventLog.last
    expect(event).to have_attributes(
      conversation_id: conversation.id,
      event_type: 'assignment_completed',
      reason: 'assigned_to_agent',
      new_assignee_id: agent.id
    )
    expect(event.metadata['real_assignment_enabled']).to be(true)
    expect(event.metadata.dig('activity_message', 'status')).to eq('enqueued')
    expect(event.metadata.dig('candidate', 'source')).to eq('manual_team_transfer')
  end

  it 'assigns a replied conversation returned to the queue and consumes the temporary marker' do
    conversation.update!(first_reply_created_at: 20.minutes.ago)
    Ibsoft::ConversationDistribution::SourceMarker.new(
      conversation: conversation,
      source: 'manual_team_transfer',
      reason: 'agent_returned_to_queue'
    ).perform
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 1, skipped: 0)
    expect(conversation.reload.assignee).to eq(agent)
    expect(conversation.first_reply_created_at).to be_present
    expect(conversation.additional_attributes['ibsoft_distribution_source_reason']).to be_nil
  end

  it 'sends assignment confirmation when the policy enables it' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: {
                                                       assignment_confirmation: {
                                                         enabled: true,
                                                         message: 'Seu atendimento foi direcionado para {{agent.name}}.',
                                                         only_before_first_reply: true
                                                       }
                                                     }
                                                   )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    message = conversation.reload.messages.template.last
    event = Ibsoft::ConversationDistribution::EventLog.last
    expect(result[:summary]).to include(scanned: 1, assigned: 1, skipped: 0)
    expect(message.content).to eq("Seu atendimento foi direcionado para #{agent.name}.")
    expect(event.metadata.dig('assignment_confirmation', 'status')).to eq('message_sent')
    expect(conversation.first_reply_created_at).to be_nil
  end

  it 'assigns with the Ibsoft executor even when Assignment V2 is disabled' do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    expect(inbox.reload.auto_assignment_v2_enabled?).to be(false)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 1, skipped: 0)
    expect(conversation.reload.assignee).to eq(agent)
  end

  it 'assigns when a team override enables distribution over a disabled channel policy' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(enabled: false)
    create(
      :ibsoft_distribution_team_policy,
      account: account,
      team: team,
      enabled: true,
      override_channel_policy: true
    )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 1, skipped: 0)
    expect(result.dig(:results, 0, :policy)).to include(source: 'team', enabled: true)
    expect(conversation.reload.assignee).to eq(agent)
  end

  it 'does not assign when a team override disables distribution over an enabled channel policy' do
    create(
      :ibsoft_distribution_team_policy,
      account: account,
      team: team,
      enabled: false,
      override_channel_policy: true
    )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 0, skipped: 1)
    expect(result[:summary][:by_reason]).to include('not_eligible' => 1)
    expect(conversation.reload.assignee).to be_nil

    event = Ibsoft::ConversationDistribution::EventLog.last
    expect(event.reason).to eq('not_eligible')
    expect(event.metadata.dig('candidate', 'reasons')).to include('policy_disabled')
  end

  it 'keeps the conversation unassigned when no team agent is online' do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return({})
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 0, skipped: 1)
    expect(result[:summary][:by_reason]).to include('no_available_agent' => 1)
    expect(conversation.reload.assignee).to be_nil

    event = Ibsoft::ConversationDistribution::EventLog.last
    expect(event).to have_attributes(
      conversation_id: conversation.id,
      event_type: 'assignment_skipped',
      reason: 'no_available_agent'
    )
  end

  it 'respects the ChatHub post-login stabilization window for recently returned agents' do
    create(
      :ibsoft_chathub_account_setting,
      account: account,
      config: {
        login_stabilization: {
          enabled: true,
          offline_threshold_minutes: 60,
          window_minutes: 10,
          max_assignments_during_window: 1,
          minimum_online_agents_to_disable: 2
        }
      }
    )
    create(
      :ibsoft_chathub_agent_presence_state,
      account: account,
      user: agent,
      current_status: 'online',
      last_offline_at: 2.hours.ago,
      last_online_at: 5.minutes.ago,
      last_status_changed_at: 5.minutes.ago
    )
    create(
      :ibsoft_distribution_event_log,
      account: account,
      inbox: inbox,
      team: team,
      conversation: conversation,
      new_assignee: agent,
      event_type: 'assignment_completed',
      created_at: 4.minutes.ago
    )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 0, skipped: 1)
    expect(result[:summary][:by_reason]).to include('no_available_agent' => 1)
    expect(conversation.reload.assignee).to be_nil
  end

  it 'does not assign outside the effective business hours' do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    travel_to Time.zone.parse('2026-07-01 10:00:00') do
      inbox.update!(working_hours_enabled: true)
      inbox.working_hours.find_by!(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
        closed_all_day: true,
        open_all_day: false
      )

      result = described_class.new(account: account).perform

      expect(result[:summary]).to include(scanned: 1, assigned: 0, skipped: 1)
      expect(result[:summary][:by_reason]).to include('outside_business_hours' => 1)
      expect(result.dig(:results, 0, :decision)).to include(action: 'wait', reason: 'outside_business_hours')
      expect(conversation.reload.assignee).to be_nil

      event = Ibsoft::ConversationDistribution::EventLog.last
      expect(event.reason).to eq('outside_business_hours')
      expect(event.metadata.dig('decision', 'action')).to eq('wait')
    end
  end

  it 'sends the configured unavailable message when the decision is notify_customer' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: { unavailable: { action: 'notify_customer',
                                                                              message: 'Aguarde um atendente ficar disponivel.' } }
                                                   )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return({})
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    message = conversation.reload.messages.outgoing.last
    expect(result[:summary]).to include(scanned: 1, assigned: 0, skipped: 1)
    expect(result.dig(:results, 0, :decision)).to include(action: 'notify_customer', action_applied: true)
    expect(result.dig(:results, 0, :decision, :action_result, :status)).to eq('message_sent')
    expect(message.content).to eq('Aguarde um atendente ficar disponivel.')
    expect(conversation.assignee).to be_nil
  end

  it 'sends the no available agent message when agents cannot receive the conversation' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: {
                                                       unavailability: {
                                                         no_available_agent: {
                                                           action: 'notify_customer',
                                                           message: 'Todos os atendentes estao ocupados.'
                                                         },
                                                         outside_business_hours: {
                                                           action: 'notify_customer',
                                                           message: 'Estamos fora do horario.'
                                                         }
                                                       }
                                                     }
                                                   )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return({})
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    message = conversation.reload.messages.outgoing.last
    expect(result[:summary]).to include(scanned: 1, assigned: 0, skipped: 1)
    expect(result.dig(:results, 0, :decision)).to include(
      action: 'notify_customer',
      reason: 'no_available_agent',
      action_applied: true
    )
    expect(message.content).to eq('Todos os atendentes estao ocupados.')
    expect(conversation.assignee).to be_nil
  end

  it 'sends the outside business hours message when the policy schedule is closed' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: {
                                                       business_hours: {
                                                         mode: 'custom',
                                                         timezone: 'America/Sao_Paulo',
                                                         schedule: [{ day_of_week: 3, closed_all_day: true }]
                                                       },
                                                       unavailability: {
                                                         no_available_agent: {
                                                           action: 'notify_customer',
                                                           message: 'Todos os atendentes estao ocupados.'
                                                         },
                                                         outside_business_hours: {
                                                           action: 'notify_customer',
                                                           message: 'Estamos fora do horario.'
                                                         }
                                                       }
                                                     }
                                                   )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    travel_to ActiveSupport::TimeZone['America/Sao_Paulo'].parse('2026-07-01 10:00:00') do
      result = described_class.new(account: account).perform

      message = conversation.reload.messages.outgoing.last
      expect(result[:summary]).to include(scanned: 1, assigned: 0, skipped: 1)
      expect(result.dig(:results, 0, :decision)).to include(
        action: 'notify_customer',
        reason: 'outside_business_hours',
        action_applied: true
      )
      expect(message.content).to eq('Estamos fora do horario.')
      expect(conversation.assignee).to be_nil
    end
  end

  it 'does not send unavailable messages while real execution is disabled' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: {
                                                       business_hours: {
                                                         mode: 'custom',
                                                         timezone: 'America/Sao_Paulo',
                                                         schedule: [{ day_of_week: 3, closed_all_day: true }]
                                                       },
                                                       unavailable: { action: 'notify_customer', message: 'Aguarde um atendente ficar disponivel.' }
                                                     }
                                                   )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(false)

    travel_to ActiveSupport::TimeZone['America/Sao_Paulo'].parse('2026-07-01 10:00:00') do
      result = described_class.new(account: account).perform

      expect(result[:summary]).to include(scanned: 1, assigned: 0, skipped: 1)
      expect(result.dig(:results, 0, :decision)).to include(action: 'notify_customer', action_applied: false)
      expect(result.dig(:results, 0, :decision, :action_result, :status)).to eq('real_assignment_disabled')
      expect(conversation.reload.messages.outgoing).to be_blank
    end
  end

  it 'moves the conversation to the configured fallback team when no agent is available' do
    fallback_team = create(:team, account: account)
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: { unavailable: { action: 'fallback_team', fallback_team_id: fallback_team.id } }
                                                   )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return({})
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    conversation.reload
    expect(result[:summary]).to include(scanned: 1, assigned: 0, skipped: 1)
    expect(result.dig(:results, 0, :decision)).to include(action: 'fallback_team', action_applied: true)
    expect(result.dig(:results, 0, :decision, :action_result, :status)).to eq('fallback_team_assigned')
    expect(conversation.team).to eq(fallback_team)
    expect(conversation.additional_attributes['ibsoft_distribution_source']).to eq('system_team_transfer')
  end

  it 'does not assign when the available agents are not members of both the inbox and the team' do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: secondary_agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(
      agent.id.to_s => 'online',
      secondary_agent.id.to_s => 'online'
    )
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 0, skipped: 1)
    expect(result[:summary][:by_reason]).to include('no_available_agent' => 1)
    expect(conversation.reload.assignee).to be_nil
  end

  it 'assigns with the Ibsoft executor when the target team disabled native auto assignment' do
    team.update!(allow_auto_assign: false)
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 1, skipped: 0)
    expect(conversation.reload.assignee).to eq(agent)
  end

  it 'does not overwrite a conversation claimed after the dry-run preview' do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    stale_preview = Ibsoft::ConversationDistribution::DryRunPreview.new(account: account).perform
    preview = instance_double(Ibsoft::ConversationDistribution::DryRunPreview, perform: stale_preview)

    create(:inbox_member, inbox: inbox, user: secondary_agent)
    conversation.update!(assignee: secondary_agent)

    allow(Ibsoft::ConversationDistribution::DryRunPreview).to receive(:new).and_return(preview)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 0, skipped: 1)
    expect(result[:summary][:by_reason]).to include('candidate_already_claimed' => 1)
    expect(conversation.reload.assignee).to eq(secondary_agent)
  end

  it 'assigns only the oldest waiting conversation when a limit is provided' do
    older_conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      team: team,
      waiting_since: 30.minutes.ago
    )
    Ibsoft::ConversationDistribution::SourceMarker.new(
      conversation: older_conversation,
      source: 'manual_team_transfer'
    ).perform
    conversation.update!(waiting_since: 10.minutes.ago)
    older_conversation.update!(waiting_since: 30.minutes.ago)
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account, limit: 1).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 1, skipped: 0)
    expect(result.dig(:results, 0, :conversation_id)).to eq(older_conversation.id)
    expect(older_conversation.reload.assignee).to eq(agent)
    expect(conversation.reload.assignee).to be_nil
  end

  it 'assigns the earliest created conversation when the policy priority is earliest_created' do
    newer_waiting_conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      team: team,
      created_at: 10.minutes.ago,
      waiting_since: 1.hour.ago
    )
    Ibsoft::ConversationDistribution::SourceMarker.new(
      conversation: newer_waiting_conversation,
      source: 'manual_team_transfer'
    ).perform
    conversation.update!(created_at: 2.hours.ago, waiting_since: 5.minutes.ago)
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: { distribution: { conversation_priority: 'earliest_created' } }
                                                   )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account, limit: 1).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 1, skipped: 0)
    expect(result.dig(:results, 0, :conversation_id)).to eq(conversation.id)
    expect(conversation.reload.assignee).to eq(agent)
    expect(newer_waiting_conversation.reload.assignee).to be_nil
  end

  it 'limits automatic assignments by the effective policy per inbox and team round' do
    second_conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      team: team,
      waiting_since: 20.minutes.ago
    )
    third_conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      team: team,
      waiting_since: 30.minutes.ago
    )
    [second_conversation, third_conversation].each do |item|
      Ibsoft::ConversationDistribution::SourceMarker.new(
        conversation: item,
        source: 'manual_team_transfer'
      ).perform
    end
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: { distribution: { max_assignments_per_round: 1 } }
                                                   )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 3, assigned: 1, skipped: 0, ignored: 2)
    expect(result[:summary][:by_reason]).to include('assigned_to_agent' => 1, 'round_limit_reached' => 2)
    expect(result[:results].count { |item| item[:status] == 'assigned' }).to eq(1)
    expect([conversation, second_conversation, third_conversation].count { |item| item.reload.assignee == agent }).to eq(1)
  end

  it 'ignores the per-round limit when the effective policy disables it' do
    second_conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      team: team,
      waiting_since: 20.minutes.ago
    )
    third_conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      team: team,
      waiting_since: 30.minutes.ago
    )
    [second_conversation, third_conversation].each do |item|
      Ibsoft::ConversationDistribution::SourceMarker.new(
        conversation: item,
        source: 'manual_team_transfer'
      ).perform
    end
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: {
                                                       distribution: {
                                                         max_assignments_per_round_enabled: false,
                                                         max_assignments_per_round: 1
                                                       }
                                                     }
                                                   )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 3, assigned: 3, skipped: 0, ignored: 0)
    expect(result[:summary][:by_reason]).not_to include('round_limit_reached')
    expect([conversation, second_conversation, third_conversation].count { |item| item.reload.assignee == agent }).to eq(3)
  end

  it 'processes a larger eligible batch when the per-round limit is disabled' do
    extra_conversations = Array.new(11) do |index|
      create(
        :conversation,
        account: account,
        inbox: inbox,
        team: team,
        waiting_since: (index + 20).minutes.ago
      )
    end
    extra_conversations.each do |item|
      Ibsoft::ConversationDistribution::SourceMarker.new(
        conversation: item,
        source: 'manual_team_transfer'
      ).perform
    end
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: {
                                                       distribution: {
                                                         max_assignments_per_round_enabled: false,
                                                         max_assignments_per_round: 1,
                                                         assignment_limit_mode: 'assignment_window',
                                                         fair_distribution_limit: 20
                                                       }
                                                     }
                                                   )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account, limit: 12).perform

    all_conversations = [conversation, *extra_conversations]
    expect(result[:summary]).to include(scanned: 12, assigned: 12, skipped: 0, ignored: 0)
    expect(result[:summary][:by_reason]).not_to include('round_limit_reached')
    expect(all_conversations.count { |item| item.reload.assignee == agent }).to eq(12)
  end

  it 'processes other eligible conversations when one candidate is ineligible' do
    blocked_team = create(:team, account: account)
    blocked_conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      team: blocked_team,
      waiting_since: 20.minutes.ago
    )
    create(
      :ibsoft_distribution_team_policy,
      account: account,
      team: blocked_team,
      enabled: false,
      override_channel_policy: true
    )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    create(:team_member, team: blocked_team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 2, assigned: 1, skipped: 1)
    expect(result[:summary][:by_reason]).to include('assigned_to_agent' => 1, 'not_eligible' => 1)
    expect(conversation.reload.assignee).to eq(agent)
    expect(blocked_conversation.reload.assignee).to be_nil
  end

  it 'distributes accumulated conversations across multiple online agents' do
    second_conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      team: team,
      waiting_since: 20.minutes.ago
    )
    Ibsoft::ConversationDistribution::SourceMarker.new(
      conversation: second_conversation,
      source: 'manual_team_transfer'
    ).perform
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: secondary_agent)
    create(:team_member, team: team, user: agent)
    create(:team_member, team: team, user: secondary_agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(
      agent.id.to_s => 'online',
      secondary_agent.id.to_s => 'online'
    )
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    assigned_users = [conversation.reload.assignee, second_conversation.reload.assignee]
    expect(result[:summary]).to include(scanned: 2, assigned: 2, skipped: 0)
    expect(assigned_users).to contain_exactly(agent, secondary_agent)
  end

  it 'uses balanced assignment to prefer the agent with fewer open conversations' do
    create(:conversation, account: account, inbox: inbox, team: team).update!(assignee: agent)
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: { distribution: { assignment_order: 'balanced' } }
                                                   )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: secondary_agent)
    create(:team_member, team: team, user: agent)
    create(:team_member, team: team, user: secondary_agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(
      agent.id.to_s => 'online',
      secondary_agent.id.to_s => 'online'
    )
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 1, skipped: 0)
    expect(conversation.reload.assignee).to eq(secondary_agent)
  end

  it 'skips agents that reached the simultaneous open conversation capacity' do
    create(:conversation, account: account, inbox: inbox, team: team).update!(assignee: agent)
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: {
                                                       distribution: {
                                                         assignment_limit_mode: 'open_conversations',
                                                         open_conversation_limit: 1
                                                       }
                                                     }
                                                   )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: secondary_agent)
    create(:team_member, team: team, user: agent)
    create(:team_member, team: team, user: secondary_agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(
      agent.id.to_s => 'online',
      secondary_agent.id.to_s => 'online'
    )
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 1, skipped: 0)
    expect(conversation.reload.assignee).to eq(secondary_agent)
  end

  it 'tries the next eligible agent when capacity is exhausted during the protected claim' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: {
                                                       distribution: {
                                                         assignment_limit_mode: 'open_conversations',
                                                         open_conversation_limit: 1
                                                       }
                                                     }
                                                   )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: secondary_agent)
    create(:team_member, team: team, user: agent)
    create(:team_member, team: team, user: secondary_agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(
      agent.id.to_s => 'online',
      secondary_agent.id.to_s => 'online'
    )
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)
    allow(Ibsoft::ConversationDistribution::AssignmentAgentSelector).to receive(:new).and_return(
      instance_double(Ibsoft::ConversationDistribution::AssignmentAgentSelector, perform: agent),
      instance_double(Ibsoft::ConversationDistribution::AssignmentAgentSelector, perform: secondary_agent)
    )
    capacity_reached_guard = instance_double(
      Ibsoft::ConversationDistribution::AgentCapacityGuard,
      perform: { status: :capacity_reached, assignment: nil }
    )
    allow(Ibsoft::ConversationDistribution::AgentCapacityGuard).to receive(:new).and_call_original
    allow(Ibsoft::ConversationDistribution::AgentCapacityGuard).to receive(:new)
      .with(account: account, agent: agent, policy: anything)
      .and_return(capacity_reached_guard)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 1, skipped: 0)
    expect(conversation.reload.assignee).to eq(secondary_agent)
  end

  it 'skips assignment when every available agent reached the policy window limit' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: {
                                                       distribution: {
                                                         assignment_limit_mode: 'assignment_window',
                                                         fair_distribution_limit: 1,
                                                         fair_distribution_window: 3600
                                                       }
                                                     }
                                                   )
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)
    Ibsoft::ConversationDistribution::AssignmentRateLimiter.new(
      account: account,
      conversation: conversation,
      agent: agent,
      policy: {
        config: {
          'distribution' => {
            'assignment_limit_mode' => 'assignment_window',
            'fair_distribution_limit' => 1,
            'fair_distribution_window' => 3600
          }
        }
      }
    ).track_assignment

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 0, skipped: 1)
    expect(result[:summary][:by_reason]).to include('no_available_agent' => 1)
    expect(conversation.reload.assignee).to be_nil
  end

  it 'respects inbox capacity limits on the legacy capacity path' do
    inbox.update!(auto_assignment_config: { max_assignment_limit: 1 })
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: secondary_agent)
    create(:team_member, team: team, user: agent)
    create(:team_member, team: team, user: secondary_agent)
    create(:conversation, account: account, inbox: inbox, team: team, assignee: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(
      agent.id.to_s => 'online',
      secondary_agent.id.to_s => 'online'
    )
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 1, skipped: 0)
    expect(conversation.reload.assignee).to eq(secondary_agent)
  end

  it 'keeps execution scoped to the requested inbox and team filters' do
    other_inbox = create(:inbox, account: account)
    other_team = create(:team, account: account)
    other_conversation = create(
      :conversation,
      account: account,
      inbox: other_inbox,
      team: other_team,
      waiting_since: 20.minutes.ago
    )
    create(:ibsoft_distribution_channel_policy, account: account, inbox: other_inbox, enabled: true)
    Ibsoft::ConversationDistribution::SourceMarker.new(
      conversation: other_conversation,
      source: 'manual_team_transfer'
    ).perform
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: other_inbox, user: agent)
    create(:team_member, team: team, user: agent)
    create(:team_member, team: other_team, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account, inbox_id: inbox.id, team_id: team.id).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 1, skipped: 0)
    expect(conversation.reload.assignee).to eq(agent)
    expect(other_conversation.reload.assignee).to be_nil
  end

  it 'does not process conversations from another account' do
    other_account = create(:account)
    other_inbox = create(:inbox, account: other_account)
    other_team = create(:team, account: other_account)
    other_agent = create(:user, account: other_account, auto_offline: false)
    other_conversation = create(
      :conversation,
      account: other_account,
      inbox: other_inbox,
      team: other_team,
      waiting_since: 20.minutes.ago
    )
    create(:ibsoft_distribution_channel_policy, account: other_account, inbox: other_inbox, enabled: true)
    Ibsoft::ConversationDistribution::SourceMarker.new(
      conversation: other_conversation,
      source: 'manual_team_transfer'
    ).perform
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: team, user: agent)
    create(:inbox_member, inbox: other_inbox, user: other_agent)
    create(:team_member, team: other_team, user: other_agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
    allow(OnlineStatusTracker).to receive(:get_available_users).with(other_account.id).and_return(other_agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 1, skipped: 0)
    expect(conversation.reload.assignee).to eq(agent)
    expect(other_conversation.reload.assignee).to be_nil
    expect(Ibsoft::ConversationDistribution::EventLog.where(account: other_account)).to be_blank
  end
end

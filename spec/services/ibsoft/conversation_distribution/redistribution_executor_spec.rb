require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::RedistributionExecutor do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:current_agent) { create(:user, account: account, auto_offline: false) }
  let(:next_agent) { create(:user, account: account, auto_offline: false) }
  let(:manual_agent) { create(:user, account: account, auto_offline: false) }
  let(:conversation) do
    create(
      :conversation,
      account: account,
      inbox: inbox,
      team: team,
      assignee: current_agent,
      first_reply_created_at: nil,
      waiting_since: 30.minutes.ago
    )
  end
  let(:assignment_event) do
    create_distribution_event(
      conversation: conversation,
      assignee: current_agent,
      event_type: 'assignment_completed',
      reason: 'assigned_to_agent',
      created_at: 20.minutes.ago
    )
  end

  before do
    account.disable_features!('assignment_v2')
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true, config: redistribution_config)
    create(:inbox_member, inbox: inbox, user: current_agent)
    create(:inbox_member, inbox: inbox, user: next_agent)
    create(:team_member, team: team, user: current_agent)
    create(:team_member, team: team, user: next_agent)
    conversation.update!(assignee: current_agent)
    assignment_event
  end

  it 'redistributes an unanswered conversation assigned by the Ibsoft executor to another online team agent' do
    account.update!(locale: 'pt_BR')
    attention_notifications = create_previous_assignee_attention_notifications
    previous_participant = create(:conversation_participant, account: account, conversation: conversation, user: current_agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(
      current_agent.id.to_s => 'online',
      next_agent.id.to_s => 'online'
    )
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = nil
    perform_enqueued_jobs(only: [EventDispatcherJob, Conversations::ActivityMessageJob]) do
      result = described_class.new(account: account).perform
    end

    expect(result[:summary]).to include(scanned: 1, redistributed: 1, skipped: 0)
    expect(result[:summary][:by_reason]).to include('first_response_timeout' => 1)
    expect(conversation.reload.assignee).to eq(next_agent)
    expect(ConversationParticipant.exists?(previous_participant.id)).to be(false)
    expect_previous_assignee_attention_synced(attention_notifications)
    expect_new_assignee_attention_created
    expect_redistribution_activity_created

    event = Ibsoft::ConversationDistribution::EventLog.order(:created_at).last
    expect_redistribution_event_logged(event)
  end

  it 'redistributes when the target team disabled native auto assignment' do
    team.update!(allow_auto_assign: false)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(
      current_agent.id.to_s => 'online',
      next_agent.id.to_s => 'online'
    )
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, redistributed: 1, skipped: 0)
    expect(conversation.reload.assignee).to eq(next_agent)
  end

  it 'tries another eligible agent when redistribution capacity changes during the protected claim' do
    create(:inbox_member, inbox: inbox, user: manual_agent)
    create(:team_member, team: team, user: manual_agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(
      current_agent.id.to_s => 'online',
      next_agent.id.to_s => 'online',
      manual_agent.id.to_s => 'online'
    )
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)
    allow(Ibsoft::ConversationDistribution::AssignmentAgentSelector).to receive(:new).and_return(
      instance_double(Ibsoft::ConversationDistribution::AssignmentAgentSelector, perform: next_agent),
      instance_double(Ibsoft::ConversationDistribution::AssignmentAgentSelector, perform: manual_agent)
    )
    capacity_reached_guard = instance_double(
      Ibsoft::ConversationDistribution::AgentCapacityGuard,
      perform: { status: :capacity_reached, assignment: nil }
    )
    allow(Ibsoft::ConversationDistribution::AgentCapacityGuard).to receive(:new).and_call_original
    allow(Ibsoft::ConversationDistribution::AgentCapacityGuard).to receive(:new)
      .with(account: account, agent: next_agent, policy: anything)
      .and_return(capacity_reached_guard)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, redistributed: 1, skipped: 0)
    expect(conversation.reload.assignee).to eq(manual_agent)
  end

  it 'does not redistribute while real execution is disabled' do
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(next_agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(false)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, redistributed: 0, skipped: 1)
    expect(result[:summary][:by_reason]).to include('real_assignment_disabled' => 1)
    expect(conversation.reload.assignee).to eq(current_agent)

    event = Ibsoft::ConversationDistribution::EventLog.order(:created_at).last
    expect(event).to have_attributes(
      conversation_id: conversation.id,
      event_type: 'redistribution_skipped',
      reason: 'real_assignment_disabled'
    )
  end

  it 'does not create duplicate skipped logs for the same conversation and reason inside the dedupe window' do
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(next_agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(false)

    expect { described_class.new(account: account).perform }.to change(Ibsoft::ConversationDistribution::EventLog, :count).by(1)
    expect { described_class.new(account: account).perform }.not_to change(Ibsoft::ConversationDistribution::EventLog, :count)
  end

  it 'keeps the conversation with the current agent when no other eligible agent is online' do
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(current_agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, redistributed: 0, skipped: 1)
    expect(result[:summary][:by_reason]).to include('no_available_agent' => 1)
    expect(conversation.reload.assignee).to eq(current_agent)
  end

  it 'ignores conversations whose timeout has not been reached yet without logging a skipped event' do
    assignment_event.update!(created_at: 2.minutes.ago, updated_at: 2.minutes.ago)
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    expect { described_class.new(account: account).perform }.not_to change(Ibsoft::ConversationDistribution::EventLog, :count)

    result = described_class.new(account: account).perform
    expect(result[:summary]).to include(scanned: 1, redistributed: 0, skipped: 0, ignored: 1)
    expect(result[:summary][:by_reason]).to include('first_response_timeout_not_reached' => 1)
  end

  it 'does not pick conversations that already received a first human response' do
    conversation.update!(first_reply_created_at: 1.minute.ago)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 0, redistributed: 0)
    expect(conversation.reload.assignee).to eq(current_agent)
  end

  it 'does not touch conversations manually reassigned after the Ibsoft assignment event' do
    create(:inbox_member, inbox: inbox, user: manual_agent)
    create(:team_member, team: team, user: manual_agent)
    conversation.update!(assignee: manual_agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(next_agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 0, redistributed: 0)
    expect(conversation.reload.assignee).to eq(manual_agent)
  end

  it 'uses the latest Ibsoft redistribution event as the next timeout reference' do
    assignment_event.update!(created_at: 40.minutes.ago, updated_at: 40.minutes.ago)
    create_distribution_event(
      conversation: conversation,
      assignee: current_agent,
      event_type: 'redistribution_completed',
      reason: 'first_response_timeout',
      created_at: 20.minutes.ago
    )
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(next_agent.id.to_s => 'online')
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, redistributed: 1)
    expect(conversation.reload.assignee).to eq(next_agent)
    expect(result.dig(:results, 0, :trigger_event_type)).to eq('redistribution_completed')
  end

  def redistribution_config
    {
      redistribution: {
        enabled: true,
        first_response_timeout_minutes: 5
      }
    }
  end

  def create_distribution_event(conversation:, assignee:, event_type:, reason:, created_at:)
    Ibsoft::ConversationDistribution::EventLog.create!(
      account: account,
      conversation: conversation,
      inbox: conversation.inbox,
      team: conversation.team,
      new_assignee: assignee,
      event_type: event_type,
      reason: reason,
      metadata: {},
      created_at: created_at,
      updated_at: created_at
    )
  end

  def create_previous_assignee_attention_notifications
    {
      stale_assignment: create_previous_assignee_notification('conversation_assignment'),
      stale_new_message: create_previous_assignee_notification('assigned_conversation_new_message'),
      stale_participating_message: create_previous_assignee_notification('participating_conversation_new_message'),
      mention: create_previous_assignee_notification('conversation_mention')
    }
  end

  def create_previous_assignee_notification(notification_type)
    create(
      :notification,
      account: account,
      user: current_agent,
      primary_actor: conversation,
      notification_type: notification_type,
      read_at: nil
    )
  end

  def expect_previous_assignee_attention_synced(notifications)
    expect(Notification.exists?(notifications.fetch(:stale_assignment).id)).to be(false)
    expect(Notification.exists?(notifications.fetch(:stale_new_message).id)).to be(false)
    expect(Notification.exists?(notifications.fetch(:stale_participating_message).id)).to be(false)
    expect(Notification.exists?(notifications.fetch(:mention).id)).to be(true)
  end

  def expect_new_assignee_attention_created
    expect(
      next_agent.notifications.where(
        account: account,
        primary_actor: conversation,
        notification_type: 'conversation_assignment',
        read_at: nil
      )
    ).to exist
  end

  def expect_redistribution_activity_created
    content = "Atendimento redistribuído automaticamente de #{current_agent.name} para #{next_agent.name} " \
              'pela redistribuição automática por exceder o tempo de espera.'

    expect(conversation.messages.activity.where(content: content)).to exist
  end

  def expect_redistribution_event_logged(event)
    expect(event).to have_attributes(
      conversation_id: conversation.id,
      event_type: 'redistribution_completed',
      reason: 'first_response_timeout',
      previous_assignee_id: current_agent.id,
      new_assignee_id: next_agent.id
    )
    expect(event.metadata['trigger_event_id']).to eq(assignment_event.id)
    expect(event.metadata.dig('activity_message', 'status')).to eq('enqueued')
  end
end

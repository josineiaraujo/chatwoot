require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::QueueReturnService do
  let(:account) { create(:account, locale: 'pt_BR') }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let(:source_team) { create(:team, account: account, allow_auto_assign: false, name: 'Comercial') }
  let(:target_team) { create(:team, account: account, allow_auto_assign: false, name: 'Suporte') }
  let(:agent) { create(:user, account: account, role: :agent, name: 'Agente Atual') }
  let(:first_reply_created_at) { 30.minutes.ago }
  let(:conversation) do
    create(
      :conversation,
      account: account,
      inbox: inbox,
      team: source_team,
      assignee: agent,
      first_reply_created_at: first_reply_created_at,
      waiting_since: 2.hours.ago
    )
  end

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: source_team, user: agent)
    create(:team_member, team: target_team, user: agent)
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)

    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive_messages(
      job_enabled?: true,
      real_assignment_enabled?: true
    )
  end

  it 'returns a replied conversation to its current team queue without erasing response history', :aggregate_failures do
    notification = create(
      :notification,
      account: account,
      user: agent,
      primary_actor: conversation,
      notification_type: 'conversation_assignment'
    )
    participant = create(:conversation_participant, account: account, conversation: conversation, user: agent)

    result = nil
    expect do
      result = described_class.new(
        conversation: conversation,
        actor: agent,
        team: source_team
      ).perform
    end.to have_enqueued_job(Ibsoft::ConversationDistribution::WatchdogJob).with(
      account_id: account.id,
      inbox_id: inbox.id,
      team_id: source_team.id
    )

    expect(result).to include(queued: true, previous_assignee: agent, team: source_team)
    expect(conversation.reload).to have_attributes(
      team_id: source_team.id,
      assignee_id: nil
    )
    expect(conversation.first_reply_created_at).to be_within(0.000001).of(first_reply_created_at)
    expect(conversation.waiting_since).to be_within(3.seconds).of(Time.current)
    expect(conversation.additional_attributes).to include(
      'ibsoft_distribution_source' => 'manual_team_transfer',
      'ibsoft_distribution_source_reason' => 'agent_returned_to_queue'
    )
    expect(Notification.exists?(notification.id)).to be(false)
    expect(ConversationParticipant.exists?(participant.id)).to be(false)
    expect(Ibsoft::ConversationDistribution::CandidateFinder.new(account: account).perform).to contain_exactly(conversation)

    event = Ibsoft::ConversationDistribution::EventLog.find(result[:event_id])
    expect(event).to have_attributes(
      event_type: 'queue_returned',
      reason: 'agent_returned_to_queue',
      previous_assignee_id: agent.id,
      new_assignee_id: nil,
      team_id: source_team.id
    )
  end

  it 'moves the conversation to another team queue' do
    described_class.new(
      conversation: conversation,
      actor: agent,
      team: target_team
    ).perform

    expect(conversation.reload).to have_attributes(
      team_id: target_team.id,
      assignee_id: nil
    )
  end

  it 'keeps the queue transfer successful when the immediate watchdog enqueue fails' do
    allow(Ibsoft::ConversationDistribution::WatchdogJob).to receive(:perform_later).and_raise(Redis::BaseError)

    result = described_class.new(
      conversation: conversation,
      actor: agent,
      team: target_team
    ).perform

    expect(result[:distribution_job]).to include(enqueued: false, error: 'Redis::BaseError')
    expect(conversation.reload).to have_attributes(
      status: 'open',
      team_id: target_team.id,
      assignee_id: nil
    )
  end

  it 'transfers a pending bot conversation to a team queue when requested by another agent' do
    another_agent = create(:user, account: account, role: :agent, name: 'Supervisor')
    agent_bot = create(:agent_bot, account: account)
    conversation.update!(status: :pending, assignee: nil, assignee_agent_bot: agent_bot)

    described_class.new(
      conversation: conversation,
      actor: another_agent,
      team: target_team,
      mode: :manual_transfer
    ).perform

    expect(conversation.reload).to have_attributes(
      status: 'open',
      team_id: target_team.id,
      assignee_id: nil,
      assignee_agent_bot_id: nil
    )
  end

  it 'rejects transferring a resolved conversation to a queue' do
    conversation.update!(status: :resolved)

    expect do
      described_class.new(
        conversation: conversation,
        actor: agent,
        team: target_team,
        mode: :manual_transfer
      ).perform
    end.to raise_error(described_class::Error, 'queue_return_resolved')
  end

  it 'rejects a manual queue transfer by a regular agent when a human is assigned' do
    another_agent = create(:user, account: account, role: :agent)

    expect do
      described_class.new(
        conversation: conversation,
        actor: another_agent,
        team: target_team,
        mode: :manual_transfer
      ).perform
    end.to raise_error(described_class::Error, 'queue_return_assigned_forbidden')

    expect(conversation.reload).to have_attributes(team_id: source_team.id, assignee_id: agent.id)
  end

  it 'allows a manual queue transfer by an administrator when a human is assigned' do
    administrator = create(:user, account: account, role: :administrator)

    described_class.new(
      conversation: conversation,
      actor: administrator,
      team: target_team,
      mode: :manual_transfer
    ).perform

    expect(conversation.reload).to have_attributes(team_id: target_team.id, assignee_id: nil)
  end

  it 'does not requeue a conversation already waiting in the selected team' do
    original_waiting_since = 45.minutes.ago
    conversation.update!(assignee: nil, waiting_since: original_waiting_since)

    expect do
      expect do
        described_class.new(
          conversation: conversation,
          actor: agent,
          team: source_team,
          mode: :manual_transfer
        ).perform
      end.to raise_error(described_class::Error, 'queue_return_already_queued')
    end.not_to have_enqueued_job(Ibsoft::ConversationDistribution::WatchdogJob)

    expect(conversation.reload.waiting_since).to be_within(0.000001).of(original_waiting_since)
  end

  it 'rejects a queue return requested by someone other than the current assignee' do
    another_agent = create(:user, account: account, role: :agent)

    expect do
      described_class.new(
        conversation: conversation,
        actor: another_agent,
        team: source_team
      ).perform
    end.to raise_error(described_class::Error, 'queue_return_actor_not_assignee')

    expect(conversation.reload.assignee).to eq(agent)
  end

  it 'rejects an unsupported queue-return mode' do
    expect do
      described_class.new(
        conversation: conversation,
        actor: agent,
        team: source_team,
        mode: :unsupported
      ).perform
    end.to raise_error(described_class::Error, 'queue_return_invalid_mode')

    expect(conversation.reload.assignee).to eq(agent)
  end

  it 'rejects a missing target team' do
    expect do
      described_class.new(conversation: conversation, actor: agent, team: nil).perform
    end.to raise_error(described_class::Error, 'queue_return_missing_team')
  end

  it 'rejects a target team from another account' do
    other_team = create(:team)

    expect do
      described_class.new(conversation: conversation, actor: agent, team: other_team).perform
    end.to raise_error(described_class::Error, 'queue_return_missing_team')

    expect(conversation.reload).to have_attributes(team_id: source_team.id, assignee_id: agent.id)
  end

  it 'rejects a self return when the conversation is not open' do
    conversation.update!(status: :pending)

    expect do
      described_class.new(conversation: conversation, actor: agent, team: source_team).perform
    end.to raise_error(described_class::Error, 'queue_return_not_open')
  end

  it 'returns an unavailable result without changing native self-unassignment behavior when distribution is disabled' do
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:job_enabled?).and_return(false)

    result = described_class.new(
      conversation: conversation,
      actor: agent,
      team: source_team,
      strict: false
    ).perform

    expect(result).to eq(queued: false, reason: 'queue_return_distribution_disabled')
    expect(conversation.reload.assignee).to eq(agent)
  end

  it 'rejects queue return while real assignment is in safe mode' do
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(false)

    expect do
      described_class.new(conversation: conversation, actor: agent, team: source_team).perform
    end.to raise_error(described_class::Error, 'queue_return_real_assignment_disabled')

    expect(conversation.reload.assignee).to eq(agent)
  end

  it 'rejects queue return when the effective policy is disabled' do
    channel_policy = Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
    channel_policy.distribution_policy.update!(enabled: false)

    expect do
      described_class.new(conversation: conversation, actor: agent, team: source_team).perform
    end.to raise_error(described_class::Error, 'queue_return_policy_disabled')
  end

  it 'rejects queue return when manual team transfers are excluded by the policy' do
    channel_policy = Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
    channel_policy.distribution_policy.update!(config: { eligible_sources: ['automation_handoff'] })

    expect do
      described_class.new(conversation: conversation, actor: agent, team: source_team).perform
    end.to raise_error(described_class::Error, 'queue_return_source_not_allowed')

    expect(conversation.reload.assignee).to eq(agent)
  end

  it 'rejects a target team controlled by native auto assignment' do
    target_team.update!(allow_auto_assign: true)

    expect do
      described_class.new(
        conversation: conversation,
        actor: agent,
        team: target_team
      ).perform
    end.to raise_error(described_class::Error, 'queue_return_native_assignment_enabled')
  end
end

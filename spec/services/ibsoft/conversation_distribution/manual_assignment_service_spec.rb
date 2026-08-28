require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::ManualAssignmentService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let(:source_team) { create(:team, account: account, allow_auto_assign: false) }
  let(:target_team) { create(:team, account: account, allow_auto_assign: false) }
  let(:actor) { create(:user, account: account, role: :agent) }
  let(:target_agent) { create(:user, account: account, role: :agent) }
  let(:conversation) do
    create(
      :conversation,
      account: account,
      inbox: inbox,
      team: source_team,
      assignee: actor,
      waiting_since: 20.minutes.ago
    )
  end

  before do
    create(:inbox_member, inbox: inbox, user: actor)
    create(:inbox_member, inbox: inbox, user: target_agent)
    create(:team_member, team: source_team, user: actor)
    create(:team_member, team: target_team, user: actor)
    create(:team_member, team: target_team, user: target_agent)
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)

    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive_messages(
      job_enabled?: true,
      real_assignment_enabled?: true
    )
  end

  it 'opens a pending conversation assigned directly to a human without entering distribution' do
    conversation.update!(status: :pending)

    expect do
      perform_assignment('agent', target_agent.id)
    end.not_to have_enqueued_job(Ibsoft::ConversationDistribution::WatchdogJob)

    expect(conversation.reload).to have_attributes(
      status: 'open',
      assignee_id: target_agent.id,
      team_id: source_team.id
    )
    expect(conversation.additional_attributes['ibsoft_distribution_source']).to be_nil
  end

  it 'opens a snoozed conversation and clears the snooze when assigning a human' do
    conversation.update!(status: :snoozed, snoozed_until: 2.hours.from_now)

    perform_assignment('agent', target_agent.id)

    expect(conversation.reload).to have_attributes(
      status: 'open',
      snoozed_until: nil,
      assignee_id: target_agent.id
    )
  end

  it 'removes stale attention and participation from the previous agent after a direct transfer' do
    notification = create(
      :notification,
      account: account,
      user: actor,
      primary_actor: conversation,
      notification_type: 'conversation_assignment'
    )
    participant = create(:conversation_participant, account: account, conversation: conversation, user: actor)

    perform_assignment('agent', target_agent.id)

    expect(Notification.exists?(notification.id)).to be(false)
    expect(ConversationParticipant.exists?(participant.id)).to be(false)
  end

  it 'rejects agent assignment for a resolved conversation' do
    conversation.update!(status: :resolved)

    expect { perform_assignment('agent', target_agent.id) }
      .to raise_error(described_class::Error, 'manual_assignment_resolved')
    expect(conversation.reload).to have_attributes(status: 'resolved', assignee_id: actor.id)
  end

  it 'opens and queues a pending conversation transferred to another team' do
    original_waiting_since = conversation.waiting_since
    conversation.update!(status: :pending)

    expect do
      perform_assignment('team', target_team.id)
    end.to have_enqueued_job(Ibsoft::ConversationDistribution::WatchdogJob).with(
      account_id: account.id,
      inbox_id: inbox.id,
      team_id: target_team.id
    )

    expect(conversation.reload).to have_attributes(
      status: 'open',
      team_id: target_team.id,
      assignee_id: nil,
      assignee_agent_bot_id: nil
    )
    expect(conversation.waiting_since).to be_within(1.second).of(original_waiting_since)
    expect(conversation.additional_attributes['ibsoft_distribution_source']).to eq('manual_team_transfer')
  end

  it 'routes a transferred conversation into the holiday after-hours policy through the immediate watchdog' do
    after_hours_policy = create(:ibsoft_after_hours_policy, account: account)
    distribution_policy = Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                                         .distribution_policy
    distribution_policy.update!(
      after_hours_policy: after_hours_policy,
      config: distribution_policy.config.deep_merge(
        'business_hours' => { 'mode' => 'always_available' },
        'unavailability' => {
          'outside_business_hours' => { 'action' => 'after_hours_policy' }
        }
      )
    )
    calendar = create(:ibsoft_business_calendar, account: account)
    create(:ibsoft_business_calendar_team_link, account: account, team: target_team, business_calendar: calendar)

    travel_to Time.zone.parse('2026-07-01 10:00:00') do
      holiday = create(
        :ibsoft_business_holiday,
        business_calendar: calendar,
        holiday_date: Time.current.in_time_zone(inbox.timezone).to_date
      )
      Rails.cache.clear

      perform_enqueued_jobs(only: Ibsoft::ConversationDistribution::WatchdogJob) do
        perform_assignment('team', target_team.id)
      end

      wait = Ibsoft::AfterHours::Wait.find_by!(conversation: conversation)
      expect(conversation.reload).to have_attributes(
        status: 'open',
        team_id: target_team.id,
        assignee_id: nil,
        assignee_agent_bot_id: nil
      )
      expect(wait).to have_attributes(
        status: 'active',
        cause: 'holiday',
        business_calendar_id: calendar.id,
        business_holiday_id: holiday.id
      )
      expect(wait.entry_message.content).to eq(after_hours_policy.holiday_message)
    end
  end

  it 'removes stale attention and participation when a team transfer clears the assignee' do
    notification = create(
      :notification,
      account: account,
      user: actor,
      primary_actor: conversation,
      notification_type: 'assigned_conversation_new_message'
    )
    participant = create(:conversation_participant, account: account, conversation: conversation, user: actor)

    perform_assignment('team', target_team.id)

    expect(Notification.exists?(notification.id)).to be(false)
    expect(ConversationParticipant.exists?(participant.id)).to be(false)
  end

  it 'routes a pending bot conversation already in the selected team into distribution' do
    agent_bot = create(:agent_bot, account: account)
    conversation.update!(status: :pending, assignee: nil, assignee_agent_bot: agent_bot)

    expect do
      perform_assignment('team', source_team.id)
    end.to have_enqueued_job(Ibsoft::ConversationDistribution::WatchdogJob)

    expect(conversation.reload).to have_attributes(
      status: 'open',
      team_id: source_team.id,
      assignee_id: nil,
      assignee_agent_bot_id: nil
    )
  end

  it 'preserves a human assignee when the selected team is unchanged' do
    conversation.update!(status: :pending)

    expect do
      perform_assignment('team', source_team.id)
    end.not_to have_enqueued_job(Ibsoft::ConversationDistribution::WatchdogJob)

    expect(conversation.reload).to have_attributes(
      status: 'open',
      team_id: source_team.id,
      assignee_id: actor.id
    )
    expect(conversation.additional_attributes['ibsoft_distribution_source']).to be_nil
  end

  it 'opens the conversation but preserves native assignment behavior when policy is disabled' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(enabled: false)
    conversation.update!(status: :pending)

    expect do
      perform_assignment('team', target_team.id)
    end.not_to have_enqueued_job(Ibsoft::ConversationDistribution::WatchdogJob)

    expect(conversation.reload).to have_attributes(status: 'open', team_id: target_team.id, assignee_id: actor.id)
    expect(conversation.additional_attributes['ibsoft_distribution_source']).to eq('manual_team_transfer')
  end

  it 'rejects team assignment for a resolved conversation' do
    conversation.update!(status: :resolved)

    expect { perform_assignment('team', target_team.id) }
      .to raise_error(described_class::Error, 'manual_assignment_resolved')
    expect(conversation.reload).to have_attributes(status: 'resolved', team_id: source_team.id, assignee_id: actor.id)
  end

  it 'rejects targets from another account' do
    other_team = create(:team)

    expect { perform_assignment('team', other_team.id) }
      .to raise_error(described_class::Error, 'manual_assignment_team_not_found')
  end

  it 'rejects malformed target identifiers without removing the current assignee' do
    expect { perform_assignment('agent', 'not-an-id') }
      .to raise_error(described_class::Error, 'manual_assignment_invalid_target')

    expect(conversation.reload.assignee).to eq(actor)
  end

  it 'rejects an unsupported assignment type before changing the conversation' do
    expect { perform_assignment('unsupported', target_agent.id) }
      .to raise_error(described_class::Error, 'manual_assignment_invalid_type')

    expect(conversation.reload).to have_attributes(team_id: source_team.id, assignee_id: actor.id)
  end

  it 'rejects fractional target identifiers instead of truncating them' do
    expect { perform_assignment('agent', target_agent.id + 0.5) }
      .to raise_error(described_class::Error, 'manual_assignment_invalid_target')

    expect(conversation.reload.assignee).to eq(actor)
  end

  it 'rejects an agent who cannot be assigned to the conversation inbox' do
    unavailable_agent = create(:user, account: account, role: :agent)

    expect { perform_assignment('agent', unavailable_agent.id) }
      .to raise_error(described_class::Error, 'manual_assignment_agent_not_found')

    expect(conversation.reload.assignee).to eq(actor)
  end

  it 'allows an account administrator even without explicit inbox membership' do
    administrator = create(:user, account: account, role: :administrator)

    perform_assignment('agent', administrator.id)

    expect(conversation.reload.assignee).to eq(administrator)
  end

  it 'allows an inbox member from another team without changing the conversation team' do
    expect(source_team.members).not_to include(target_agent)

    perform_assignment('agent', target_agent.id)

    expect(conversation.reload).to have_attributes(
      assignee_id: target_agent.id,
      team_id: source_team.id
    )
  end

  it 'validates only the target agent without materializing every assignable agent' do
    expect_any_instance_of(Inbox).not_to receive(:assignable_agents) # rubocop:disable RSpec/AnyInstance

    perform_assignment('agent', target_agent.id)

    expect(conversation.reload.assignee).to eq(target_agent)
  end

  it 'keeps a completed team transfer successful when the immediate watchdog enqueue fails' do
    conversation.update!(status: :pending)
    allow(Ibsoft::ConversationDistribution::WatchdogJob).to receive(:perform_later).and_raise(Redis::BaseError)

    result = perform_assignment('team', target_team.id)

    expect(result[:distribution_enqueued]).to be(false)
    expect(conversation.reload).to have_attributes(
      status: 'open',
      team_id: target_team.id,
      assignee_id: nil
    )
  end

  it 'rejects a regular agent transferring a conversation that already has a human assignee' do
    regular_agent = create(:user, account: account, role: :agent)

    expect do
      described_class.new(
        conversation: conversation,
        actor: regular_agent,
        assignment_type: 'team',
        target_id: target_team.id
      ).perform
    end.to raise_error(described_class::Error, 'manual_assignment_assigned_forbidden')

    expect(conversation.reload).to have_attributes(team_id: source_team.id, assignee_id: actor.id)
  end

  it 'allows a regular agent to assign an unassigned conversation' do
    regular_agent = create(:user, account: account, role: :agent)
    create(:inbox_member, inbox: inbox, user: regular_agent)
    conversation.update!(assignee: nil)

    described_class.new(
      conversation: conversation,
      actor: regular_agent,
      assignment_type: 'agent',
      target_id: regular_agent.id
    ).perform

    expect(conversation.reload.assignee).to eq(regular_agent)
  end

  it 'removes the current assignee without queueing when the conversation has no department' do
    conversation.update!(team: nil)

    expect do
      result = perform_assignment('agent', 0)
      expect(result).to include(queue_returned: false, distribution_enqueued: false)
    end.not_to have_enqueued_job(Ibsoft::ConversationDistribution::WatchdogJob)

    expect(conversation.reload).to have_attributes(team_id: nil, assignee_id: nil, assignee_agent_bot_id: nil)
  end

  it 'removes the department without enqueueing distribution when the target is zero' do
    result = perform_assignment('team', 0)

    expect(result).to include(distribution_enqueued: false, queue_returned: false)
    expect(conversation.reload).to have_attributes(status: 'open', team_id: nil, assignee_id: actor.id)
  end

  private

  def perform_assignment(type, target_id)
    described_class.new(
      conversation: conversation,
      actor: actor,
      assignment_type: type,
      target_id: target_id
    ).perform
  end
end

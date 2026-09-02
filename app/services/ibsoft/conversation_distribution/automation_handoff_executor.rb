# rubocop:disable Metrics/ClassLength
class Ibsoft::ConversationDistribution::AutomationHandoffExecutor
  EVENT_COMPLETED = 'automation_handoff_completed'.freeze
  EVENT_CLOSE_COMPLETED = 'automation_close_completed'.freeze
  EVENT_CLOSE_WARNING_SENT = 'automation_close_warning_sent'.freeze
  EVENT_SKIPPED = 'automation_handoff_skipped'.freeze
  REASON_STALLED = 'automation_stalled'.freeze
  REASON_DISABLED = 'real_assignment_disabled'.freeze
  REASON_CHANGED = 'candidate_already_changed'.freeze
  REASON_WARNING_DELIVERY_FAILED = 'warning_delivery_failed'.freeze
  SOURCE_REASON = 'automation_stalled'.freeze

  def initialize(account:, inbox_id: nil, limit: Ibsoft::ConversationDistribution::AutomationHandoffCandidateFinder::DEFAULT_LIMIT)
    @account = account
    @inbox_id = inbox_id
    @limit = limit
  end

  def perform
    candidates = candidate_finder.perform
    results = candidates.map { |candidate| process_candidate(candidate) }

    {
      generated_at: Time.current.iso8601,
      real_assignment_enabled: real_assignment_enabled?,
      filters: filters_payload,
      limit: candidate_finder.safe_limit,
      summary: summary_payload(results),
      results: results
    }
  end

  private

  attr_reader :account, :inbox_id, :limit

  def candidate_finder
    @candidate_finder ||= Ibsoft::ConversationDistribution::AutomationHandoffCandidateFinder.new(
      account: account,
      inbox_id: inbox_id,
      limit: limit
    )
  end

  def process_candidate(candidate)
    conversation = account.conversations.find_by(id: candidate[:conversation_id])
    return result_payload(candidate, 'skipped', REASON_CHANGED) if conversation.blank?

    policy = automation_policy(candidate)

    return skipped_result(conversation, candidate, policy, REASON_CHANGED) if policy.blank?
    return skipped_result(conversation, candidate, policy, REASON_DISABLED) unless real_assignment_enabled?

    return schedule_close_warning(conversation, candidate, policy) if close_warning_required?(policy)

    transition = claim_and_apply_action(conversation, policy, candidate)
    return skipped_result(conversation, candidate, policy, REASON_CHANGED) if transition.blank?

    notifications = post_action_notifications(transition[:conversation], policy)
    log_completed(transition, candidate, policy, notifications)

    result_payload(candidate, result_status(policy), REASON_STALLED)
  end

  def close_warning_required?(policy)
    policy.close_conversation? && policy.close_warning_enabled?
  end

  def schedule_close_warning(conversation, candidate, policy)
    transition = claim_and_schedule_close(conversation, policy, candidate)
    return skipped_result(conversation, candidate, policy, REASON_CHANGED) if transition.blank?

    if transition[:status] == 'warning_failed'
      return skipped_result(
        conversation,
        candidate,
        policy,
        REASON_WARNING_DELIVERY_FAILED,
        customer_message: transition[:customer_message]
      )
    end

    enqueue_scheduled_close(transition[:schedule])
    log_close_warning_sent(transition, candidate, policy)

    result_payload(candidate, 'warning_sent', REASON_STALLED).merge(
      schedule_id: transition[:schedule].id,
      close_at: transition[:schedule].close_at.iso8601
    )
  end

  def claim_and_schedule_close(conversation, policy, candidate)
    Conversation.transaction do
      locked_conversation = lock_candidate(conversation, policy, candidate)
      next if locked_conversation.blank?
      next if already_processed_after_last_bot_message?(locked_conversation, candidate)
      next if close_schedule_exists?(locked_conversation)

      create_close_schedule(locked_conversation, policy, candidate)
    end
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def create_close_schedule(conversation, policy, candidate)
    notification = close_warning_notification(conversation, policy)
    return warning_failed_transition(conversation, notification) unless notification[:applied]

    schedule = Ibsoft::ConversationDistribution::AutomationCloseSchedule.create!(
      close_schedule_attributes(conversation, policy, candidate, notification)
    )
    { conversation: conversation, schedule: schedule, customer_message: notification }
  end

  def close_warning_notification(conversation, policy)
    Ibsoft::ConversationDistribution::AutomationCustomerMessageNotifier.new(
      conversation: conversation,
      policy: policy,
      phase: :close_warning
    ).perform
  end

  def warning_failed_transition(conversation, notification)
    {
      status: 'warning_failed',
      conversation: conversation,
      customer_message: notification
    }
  end

  def close_schedule_attributes(conversation, policy, candidate, notification)
    {
      account: account,
      conversation: conversation,
      automation_handoff_policy: policy,
      trigger_message_id: candidate[:last_bot_message_id],
      warning_message_id: notification[:message_id],
      expected_team_id: conversation.team_id,
      expected_agent_bot_id: conversation.assignee_agent_bot_id,
      expected_policy_updated_at: policy.updated_at,
      close_at: Time.current + policy.close_warning_delay_minutes.minutes
    }
  end

  def close_schedule_exists?(conversation)
    Ibsoft::ConversationDistribution::AutomationCloseSchedule.exists?(conversation: conversation)
  end

  def enqueue_scheduled_close(schedule)
    Ibsoft::ConversationDistribution::AutomationCloseJob
      .set(wait_until: schedule.close_at)
      .perform_later(schedule.id)
  rescue StandardError => e
    Rails.logger.error(
      '[Ibsoft::ConversationDistribution] automation close enqueue failed ' \
      "(schedule=#{schedule.id}): #{e.class} - #{e.message}"
    )
  end

  def automation_policy(candidate)
    Ibsoft::ConversationDistribution::AutomationHandoffPolicy.find_by(
      account: account,
      id: candidate[:policy_id]
    )
  end

  def claim_and_apply_action(conversation, policy, candidate)
    Conversation.transaction do
      locked_conversation = lock_candidate(conversation, policy, candidate)
      next if locked_conversation.blank?
      next if already_processed_after_last_bot_message?(locked_conversation, candidate)

      previous_team = locked_conversation.team
      Ibsoft::ConversationOwnership::Clearer.perform(locked_conversation)
      locked_conversation.update!(action_attributes(locked_conversation, policy, previous_team, candidate))

      { conversation: locked_conversation, previous_team: previous_team }
    end
  end

  def lock_candidate(conversation, policy, candidate)
    return unless policy.enabled?
    return if policy.forward_to_team? && policy.target_team.blank?

    locked_conversation = account.conversations
                                 .pending
                                 .where(assignee_id: nil)
                                 .where(
                                   id: conversation.id,
                                   inbox_id: policy.inbox_id,
                                   first_reply_created_at: nil
                                 )
                                 .lock('FOR UPDATE SKIP LOCKED')
                                 .first
    return if locked_conversation.blank?

    signal = Ibsoft::ConversationDistribution::AutomationWaitingSignal.new(
      conversation: locked_conversation,
      stale_after_minutes: policy.stale_after_minutes,
      expected_message_id: candidate[:last_bot_message_id]
    )
    locked_conversation if signal.eligible?
  end

  def action_attributes(conversation, policy, previous_team, candidate)
    return close_attributes(conversation, policy, candidate) if policy.close_conversation?

    {
      status: :open,
      team: policy.target_team,
      waiting_since: conversation.waiting_since || parsed_last_bot_message_at(candidate) || Time.current,
      additional_attributes: handoff_marked_attributes(conversation, policy, previous_team, candidate)
    }
  end

  def close_attributes(conversation, policy, candidate)
    {
      status: :resolved,
      additional_attributes: close_marked_attributes(conversation, policy, candidate)
    }
  end

  def handoff_marked_attributes(conversation, policy, previous_team, candidate)
    attributes = (conversation.additional_attributes || {}).deep_dup
    clear_close_markers(attributes)
    attributes[Ibsoft::ConversationDistribution::SourceResolver::ATTRIBUTE_KEY] = 'system_team_transfer'
    attributes[Ibsoft::ConversationDistribution::SourceMarker::MARKED_AT_KEY] = Time.current.iso8601
    attributes[Ibsoft::ConversationDistribution::SourceMarker::REASON_KEY] = SOURCE_REASON
    attributes['ibsoft_automation_handoff_policy_id'] = policy.id
    attributes['ibsoft_automation_handoff_previous_team_id'] = previous_team&.id
    attributes['ibsoft_automation_handoff_target_team_id'] = policy.target_team_id
    attributes['ibsoft_automation_handoff_at'] = Time.current.iso8601
    attributes['ibsoft_automation_last_bot_message_id'] = candidate[:last_bot_message_id]
    attributes
  end

  def close_marked_attributes(conversation, policy, candidate)
    attributes = (conversation.additional_attributes || {}).deep_dup
    clear_handoff_markers(attributes)
    attributes.delete(Ibsoft::ConversationDistribution::SourceResolver::ATTRIBUTE_KEY)
    attributes.delete(Ibsoft::ConversationDistribution::SourceMarker::MARKED_AT_KEY)
    attributes.delete(Ibsoft::ConversationDistribution::SourceMarker::REASON_KEY)
    attributes['ibsoft_automation_close_policy_id'] = policy.id
    attributes['ibsoft_automation_close_at'] = Time.current.iso8601
    attributes['ibsoft_automation_last_bot_message_id'] = candidate[:last_bot_message_id]
    attributes
  end

  def clear_handoff_markers(attributes)
    attributes.delete('ibsoft_automation_handoff_policy_id')
    attributes.delete('ibsoft_automation_handoff_previous_team_id')
    attributes.delete('ibsoft_automation_handoff_target_team_id')
    attributes.delete('ibsoft_automation_handoff_at')
  end

  def clear_close_markers(attributes)
    attributes.delete('ibsoft_automation_close_policy_id')
    attributes.delete('ibsoft_automation_close_at')
  end

  def post_action_notifications(conversation, policy)
    {
      activity_message: activity_message_result(conversation, policy),
      customer_message: customer_message_result(conversation, policy)
    }
  end

  def activity_message_result(conversation, policy)
    Ibsoft::ConversationDistribution::ActivityMessageNotifier.new(
      conversation: conversation,
      action: activity_action(policy),
      target_team: policy.target_team,
      stale_after_minutes: policy.stale_after_minutes
    ).perform
  end

  def customer_message_result(conversation, policy)
    phase = policy.close_conversation? ? :close_final : :forward
    Ibsoft::ConversationDistribution::AutomationCustomerMessageNotifier.new(
      conversation: conversation,
      policy: policy,
      phase: phase
    ).perform
  end

  def log_completed(transition, candidate, policy, notifications)
    event_logger.log(
      conversation: transition[:conversation],
      event_type: completed_event_type(policy),
      reason: REASON_STALLED,
      payload: {
        metadata: {
          candidate: candidate,
          policy: policy.payload,
          previous_team: resource_payload(transition[:previous_team]),
          target_team: resource_payload(policy.target_team),
          real_assignment_enabled: real_assignment_enabled?,
          activity_message: notifications[:activity_message],
          customer_message: notifications[:customer_message]
        }
      }
    )
  end

  def log_close_warning_sent(transition, candidate, policy)
    event_logger.log(
      conversation: transition[:conversation],
      event_type: EVENT_CLOSE_WARNING_SENT,
      reason: REASON_STALLED,
      payload: {
        metadata: {
          candidate: candidate,
          policy: policy.payload,
          schedule: transition[:schedule].attributes.slice(
            'id', 'trigger_message_id', 'warning_message_id', 'expected_team_id',
            'expected_agent_bot_id', 'expected_policy_updated_at', 'close_at'
          ),
          customer_message: transition[:customer_message]
        }
      }
    )
  end

  def skipped_result(conversation, candidate, policy, reason, metadata = {})
    event_logger.log(
      conversation: conversation,
      event_type: EVENT_SKIPPED,
      reason: reason,
      payload: {
        metadata: {
          candidate: candidate,
          policy: policy&.payload,
          real_assignment_enabled: real_assignment_enabled?
        }.merge(metadata),
        options: { dedupe: true }
      }
    )

    result_payload(candidate, 'skipped', reason)
  end

  def result_payload(candidate, status, reason)
    candidate.slice(
      :conversation_id,
      :display_id,
      :inbox_id,
      :inbox_name,
      :previous_team_id,
      :previous_team_name,
      :target_team_id,
      :target_team_name,
      :policy_id,
      :stale_after_minutes,
      :timeout_action,
      :last_bot_message_id,
      :last_bot_message_at,
      :last_activity_at,
      :waited_seconds,
      :automation_signal
    ).merge(status: status, reason: reason)
  end

  def summary_payload(results)
    {
      scanned: results.length,
      handoffed: results.count { |result| result[:status] == 'handoffed' },
      closed: results.count { |result| result[:status] == 'closed' },
      warnings_sent: results.count { |result| result[:status] == 'warning_sent' },
      skipped: results.count { |result| result[:status] == 'skipped' },
      ignored: results.count { |result| result[:status] == 'ignored' },
      by_reason: results.pluck(:reason).tally
    }
  end

  def already_processed_after_last_bot_message?(conversation, candidate)
    last_bot_message_at = parsed_last_bot_message_at(candidate)
    return false if last_bot_message_at.blank?

    Ibsoft::ConversationDistribution::EventLog
      .where(
        account: account,
        conversation: conversation,
        event_type: [EVENT_COMPLETED, EVENT_CLOSE_COMPLETED, EVENT_CLOSE_WARNING_SENT]
      )
      .exists?(created_at: last_bot_message_at..)
  rescue ArgumentError, TypeError
    false
  end

  def parsed_last_bot_message_at(candidate)
    value = candidate[:last_bot_message_at]
    return value if value.respond_to?(:in_time_zone)
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def completed_event_type(policy)
    policy.close_conversation? ? EVENT_CLOSE_COMPLETED : EVENT_COMPLETED
  end

  def activity_action(policy)
    policy.close_conversation? ? :automation_close_completed : :automation_handoff_completed
  end

  def result_status(policy)
    policy.close_conversation? ? 'closed' : 'handoffed'
  end

  def resource_payload(resource)
    return if resource.blank?

    {
      id: resource.id,
      name: resource.name
    }
  end

  def filters_payload
    { inbox_id: inbox_id.presence }
  end

  def real_assignment_enabled?
    Ibsoft::ConversationDistribution::ExecutionConfig.real_assignment_enabled?
  end

  def event_logger
    @event_logger ||= Ibsoft::ConversationDistribution::EventLogger.new(account: account)
  end
end
# rubocop:enable Metrics/ClassLength

# rubocop:disable Metrics/ClassLength
class Ibsoft::ConversationDistribution::AutomationCloseExecutor
  EVENT_COMPLETED = 'automation_close_completed'.freeze
  EVENT_CANCELLED = 'automation_close_cancelled'.freeze
  REASON_STALLED = 'automation_stalled'.freeze
  REASON_CUSTOMER_REPLIED = 'customer_replied'.freeze
  REASON_CONVERSATION_CHANGED = 'conversation_changed'.freeze
  REASON_WARNING_DELIVERY_FAILED = 'warning_delivery_failed'.freeze

  def initialize(account:, schedule_id: nil, inbox_id: nil,
                 limit: Ibsoft::ConversationDistribution::AutomationHandoffCandidateFinder::DEFAULT_LIMIT)
    @account = account
    @schedule_id = schedule_id
    @inbox_id = inbox_id
    @limit = limit
  end

  def perform
    results = schedules.filter_map { |schedule| process_schedule(schedule.id) }

    {
      generated_at: Time.current.iso8601,
      filters: { inbox_id: inbox_id.presence, schedule_id: schedule_id.presence },
      limit: safe_limit,
      summary: summary_payload(results),
      results: results
    }
  end

  private

  attr_reader :account, :schedule_id, :inbox_id, :limit

  def schedules
    scope = Ibsoft::ConversationDistribution::AutomationCloseSchedule.where(account: account)
    scope = scope.where(id: schedule_id) if schedule_id.present?
    scope = scope.due if schedule_id.blank?
    scope = scope.joins(:automation_handoff_policy).where(policy_table => { inbox_id: inbox_id }) if inbox_id.present?
    scope.order(:close_at, :id).limit(safe_limit)
  end

  def process_schedule(id)
    transition = claim_schedule(id)
    return if transition.blank?
    return pending_result(transition[:schedule]) if transition[:status] == 'pending'

    if transition[:status] == 'cancelled'
      log_cancelled(transition)
      return result_payload(transition, 'cancelled')
    end

    notifications = post_close_notifications(transition)
    log_completed(transition, notifications)
    result_payload(transition, 'closed')
  rescue StandardError => e
    Rails.logger.error(
      '[Ibsoft::ConversationDistribution] scheduled automation close failed ' \
      "(schedule=#{id}): #{e.class} - #{e.message}"
    )
    { schedule_id: id, status: 'skipped', reason: e.class.name }
  end

  def claim_schedule(id)
    Ibsoft::ConversationDistribution::AutomationCloseSchedule.transaction do
      schedule = locked_schedule(id)
      next if schedule.blank?
      next({ status: 'pending', schedule: schedule }) if schedule.close_at.future?

      policy = locked_policy(schedule)
      conversation = account.conversations.lock.find_by(id: schedule.conversation_id)
      reason = cancellation_reason(schedule, conversation, policy)
      if reason.present?
        snapshot = transition_payload(schedule, conversation, policy, reason)
        schedule.destroy!
        next snapshot.merge(status: 'cancelled')
      end

      Ibsoft::ConversationOwnership::Clearer.perform(conversation)
      conversation.update!(close_attributes(conversation, policy, schedule))
      snapshot = transition_payload(schedule, conversation, policy, REASON_STALLED)
      schedule.destroy!
      snapshot.merge(status: 'closed')
    end
  end

  def locked_schedule(id)
    Ibsoft::ConversationDistribution::AutomationCloseSchedule
      .where(account: account, id: id)
      .lock('FOR UPDATE SKIP LOCKED')
      .first
  end

  def locked_policy(schedule)
    Ibsoft::ConversationDistribution::AutomationHandoffPolicy
      .where(account: account, id: schedule.automation_handoff_policy_id)
      .lock
      .first
  end

  def cancellation_reason(schedule, conversation, policy)
    return REASON_CONVERSATION_CHANGED unless conversation_state_unchanged?(schedule, conversation, policy)

    warning_message = warning_message(schedule, conversation)
    return REASON_CONVERSATION_CHANGED unless valid_warning_message?(warning_message)
    return REASON_WARNING_DELIVERY_FAILED if warning_message.failed?
    return REASON_CUSTOMER_REPLIED if customer_replied_after?(conversation, warning_message)
    return REASON_CONVERSATION_CHANGED unless latest_public_message_id(conversation) == warning_message.id

    nil
  end

  def conversation_state_unchanged?(schedule, conversation, policy)
    conversation.present? &&
      valid_policy?(policy, conversation) &&
      policy_unchanged?(schedule, policy) &&
      waiting_for_customer?(conversation) &&
      routing_unchanged?(schedule, conversation)
  end

  def valid_warning_message?(message)
    message.present? && automation_warning_message?(message)
  end

  def valid_policy?(policy, conversation)
    policy&.enabled? &&
      policy.close_conversation? &&
      policy.close_warning_enabled? &&
      policy.inbox_id == conversation.inbox_id
  end

  def waiting_for_customer?(conversation)
    conversation.pending? && conversation.assignee_id.blank? && conversation.first_reply_created_at.blank?
  end

  def policy_unchanged?(schedule, policy)
    return false if schedule.expected_policy_updated_at.blank?

    schedule.expected_policy_updated_at == policy.updated_at
  end

  def routing_unchanged?(schedule, conversation)
    schedule.expected_team_id == conversation.team_id &&
      schedule.expected_agent_bot_id == conversation.assignee_agent_bot_id
  end

  def warning_message(schedule, conversation)
    conversation.messages.chat.find_by(id: schedule.warning_message_id)
  end

  def automation_warning_message?(message)
    message.content_attributes.to_h.dig(
      'ibsoft_conversation_distribution',
      'action'
    ) == Ibsoft::ConversationDistribution::AutomationCustomerMessageNotifier::ACTION_BY_PHASE.fetch(:close_warning)
  end

  def customer_replied_after?(conversation, warning_message)
    conditions = [
      'messages.created_at > :created_at OR (messages.created_at = :created_at AND messages.id > :id)',
      { created_at: warning_message.created_at, id: warning_message.id }
    ]
    conversation.messages.chat.incoming.exists?(conditions)
  end

  def latest_public_message_id(conversation)
    conversation.messages.chat.reorder(created_at: :desc, id: :desc).pick(:id)
  end

  def close_attributes(conversation, policy, schedule)
    {
      status: :resolved,
      additional_attributes: close_marked_attributes(conversation, policy, schedule)
    }
  end

  def close_marked_attributes(conversation, policy, schedule)
    attributes = (conversation.additional_attributes || {}).deep_dup
    clear_distribution_markers(attributes)
    attributes['ibsoft_automation_close_policy_id'] = policy.id
    attributes['ibsoft_automation_close_at'] = Time.current.iso8601
    attributes['ibsoft_automation_last_bot_message_id'] = schedule.trigger_message_id
    attributes
  end

  def clear_distribution_markers(attributes)
    %w[
      ibsoft_distribution_source
      ibsoft_distribution_source_marked_at
      ibsoft_distribution_source_reason
      ibsoft_automation_handoff_policy_id
      ibsoft_automation_handoff_previous_team_id
      ibsoft_automation_handoff_target_team_id
      ibsoft_automation_handoff_at
    ].each { |key| attributes.delete(key) }
  end

  def transition_payload(schedule, conversation, policy, reason)
    {
      schedule: schedule.attributes.slice(
        'id', 'conversation_id', 'trigger_message_id', 'warning_message_id',
        'expected_team_id', 'expected_agent_bot_id', 'expected_policy_updated_at', 'close_at'
      ),
      conversation: conversation,
      policy: policy,
      reason: reason
    }
  end

  def post_close_notifications(transition)
    conversation = transition[:conversation]
    policy = transition[:policy]
    {
      activity_message: Ibsoft::ConversationDistribution::ActivityMessageNotifier.new(
        conversation: conversation,
        action: :automation_close_completed,
        stale_after_minutes: policy.stale_after_minutes
      ).perform,
      customer_message: Ibsoft::ConversationDistribution::AutomationCustomerMessageNotifier.new(
        conversation: conversation,
        policy: policy,
        phase: :close_final
      ).perform
    }
  end

  def log_completed(transition, notifications)
    event_logger.log(
      conversation: transition[:conversation],
      event_type: EVENT_COMPLETED,
      reason: REASON_STALLED,
      payload: {
        metadata: {
          schedule: transition[:schedule],
          policy: transition[:policy].payload,
          activity_message: notifications[:activity_message],
          customer_message: notifications[:customer_message]
        }
      }
    )
  end

  def log_cancelled(transition)
    event_logger.log(
      conversation: transition[:conversation],
      event_type: EVENT_CANCELLED,
      reason: transition[:reason],
      payload: {
        metadata: {
          schedule: transition[:schedule],
          policy: transition[:policy]&.payload
        }
      }
    )
  end

  def result_payload(transition, status)
    {
      schedule_id: transition.dig(:schedule, 'id'),
      conversation_id: transition.dig(:schedule, 'conversation_id'),
      status: status,
      reason: transition[:reason]
    }
  end

  def pending_result(schedule)
    {
      schedule_id: schedule.id,
      conversation_id: schedule.conversation_id,
      status: 'pending',
      reason: 'close_not_due'
    }
  end

  def summary_payload(results)
    {
      scanned: results.length,
      closed: results.count { |result| result[:status] == 'closed' },
      cancelled: results.count { |result| result[:status] == 'cancelled' },
      skipped: results.count { |result| result[:status] == 'skipped' },
      ignored: results.count { |result| result[:status] == 'pending' },
      by_reason: results.pluck(:reason).tally
    }
  end

  def safe_limit
    requested = limit.to_i
    requested = Ibsoft::ConversationDistribution::AutomationHandoffCandidateFinder::DEFAULT_LIMIT unless requested.positive?
    [requested, Ibsoft::ConversationDistribution::AutomationHandoffCandidateFinder::MAX_LIMIT].min
  end

  def policy_table
    Ibsoft::ConversationDistribution::AutomationHandoffPolicy.table_name
  end

  def event_logger
    @event_logger ||= Ibsoft::ConversationDistribution::EventLogger.new(account: account)
  end
end
# rubocop:enable Metrics/ClassLength

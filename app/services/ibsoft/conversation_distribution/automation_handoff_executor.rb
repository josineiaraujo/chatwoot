# rubocop:disable Metrics/ClassLength
class Ibsoft::ConversationDistribution::AutomationHandoffExecutor
  EVENT_COMPLETED = 'automation_handoff_completed'.freeze
  EVENT_SKIPPED = 'automation_handoff_skipped'.freeze
  REASON_STALLED = 'automation_stalled'.freeze
  REASON_DISABLED = 'real_assignment_disabled'.freeze
  REASON_CHANGED = 'candidate_already_changed'.freeze
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
    conversation = account.conversations.find(candidate[:conversation_id])
    policy = automation_policy(candidate)

    return skipped_result(conversation, candidate, policy, REASON_DISABLED) unless real_assignment_enabled?

    handoff = claim_and_handoff(conversation, policy)
    return skipped_result(conversation, candidate, policy, REASON_CHANGED) if handoff.blank?

    notifications = post_handoff_actions(handoff[:conversation], policy)
    log_handoff_completed(handoff, candidate, policy, notifications)

    result_payload(candidate, 'handoffed', REASON_STALLED)
  end

  def automation_policy(candidate)
    Ibsoft::ConversationDistribution::AutomationHandoffPolicy.find_by!(
      account: account,
      id: candidate[:policy_id]
    )
  end

  def claim_and_handoff(conversation, policy)
    Conversation.transaction do
      locked_conversation = lock_candidate(conversation, policy)
      next if locked_conversation.blank?
      next if already_handoffed_after_last_activity?(locked_conversation)

      previous_team = locked_conversation.team
      locked_conversation.update!(
        status: :open,
        team: policy.target_team,
        assignee: nil,
        assignee_agent_bot: nil,
        waiting_since: locked_conversation.waiting_since || locked_conversation.last_activity_at || Time.current,
        additional_attributes: marked_attributes(locked_conversation, policy, previous_team)
      )

      { conversation: locked_conversation, previous_team: previous_team }
    end
  end

  def lock_candidate(conversation, policy)
    account.conversations
           .pending
           .where(assignee_id: nil)
           .where(
             id: conversation.id,
             inbox_id: policy.inbox_id,
             first_reply_created_at: nil
           )
           .where('last_activity_at <= ?', policy.stale_after_minutes.minutes.ago)
           .lock('FOR UPDATE SKIP LOCKED')
           .first
  end

  def marked_attributes(conversation, policy, previous_team)
    attributes = (conversation.additional_attributes || {}).deep_dup
    attributes[Ibsoft::ConversationDistribution::SourceResolver::ATTRIBUTE_KEY] = 'system_team_transfer'
    attributes[Ibsoft::ConversationDistribution::SourceMarker::MARKED_AT_KEY] = Time.current.iso8601
    attributes[Ibsoft::ConversationDistribution::SourceMarker::REASON_KEY] = SOURCE_REASON
    attributes['ibsoft_automation_handoff_policy_id'] = policy.id
    attributes['ibsoft_automation_handoff_previous_team_id'] = previous_team&.id
    attributes['ibsoft_automation_handoff_target_team_id'] = policy.target_team_id
    attributes['ibsoft_automation_handoff_at'] = Time.current.iso8601
    attributes
  end

  def post_handoff_actions(conversation, policy)
    {
      activity_message: activity_message_result(conversation, policy),
      customer_message: customer_message_result(conversation, policy)
    }
  end

  def activity_message_result(conversation, policy)
    Ibsoft::ConversationDistribution::ActivityMessageNotifier.new(
      conversation: conversation,
      action: :automation_handoff_completed,
      target_team: policy.target_team
    ).perform
  end

  def customer_message_result(conversation, policy)
    return action_result(false, 'disabled') unless policy.customer_message_enabled?
    return action_result(false, 'blank_message') if policy.customer_message.blank?

    message = Messages::MessageBuilder.new(nil, conversation, customer_message_params(policy)).perform
    action_result(true, 'message_sent', message_id: message.id)
  rescue StandardError => e
    Rails.logger.error("[Ibsoft::ConversationDistribution] automation handoff customer message failed: #{e.class} - #{e.message}")
    action_result(false, 'error', error: e.class.name)
  end

  def customer_message_params(policy)
    {
      content: policy.customer_message,
      private: false,
      message_type: :template,
      content_attributes: {
        ibsoft_conversation_distribution: {
          action: 'automation_handoff',
          reason: REASON_STALLED,
          target_team_id: policy.target_team_id
        }
      }
    }
  end

  def log_handoff_completed(handoff, candidate, policy, notifications)
    event_logger.log(
      conversation: handoff[:conversation],
      event_type: EVENT_COMPLETED,
      reason: REASON_STALLED,
      payload: {
        metadata: {
          candidate: candidate,
          policy: policy.payload,
          previous_team: resource_payload(handoff[:previous_team]),
          target_team: resource_payload(policy.target_team),
          real_assignment_enabled: real_assignment_enabled?,
          activity_message: notifications[:activity_message],
          customer_message: notifications[:customer_message]
        }
      }
    )
  end

  def skipped_result(conversation, candidate, policy, reason)
    event_logger.log(
      conversation: conversation,
      event_type: EVENT_SKIPPED,
      reason: reason,
      payload: {
        metadata: {
          candidate: candidate,
          policy: policy.payload,
          real_assignment_enabled: real_assignment_enabled?
        },
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
      :last_activity_at,
      :waited_seconds,
      :automation_signal
    ).merge(status: status, reason: reason)
  end

  def summary_payload(results)
    {
      scanned: results.length,
      handoffed: results.count { |result| result[:status] == 'handoffed' },
      skipped: results.count { |result| result[:status] == 'skipped' },
      ignored: results.count { |result| result[:status] == 'ignored' },
      by_reason: results.pluck(:reason).tally
    }
  end

  def already_handoffed_after_last_activity?(conversation)
    Ibsoft::ConversationDistribution::EventLog
      .where(account: account, conversation: conversation, event_type: EVENT_COMPLETED)
      .exists?(created_at: conversation.last_activity_at..)
  end

  def resource_payload(resource)
    return if resource.blank?

    {
      id: resource.id,
      name: resource.name
    }
  end

  def action_result(applied, status, metadata = {})
    { applied: applied, status: status }.merge(metadata)
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

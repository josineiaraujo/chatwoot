# rubocop:disable Metrics/ClassLength
class Ibsoft::ConversationDistribution::AssignmentExecutor
  EVENT_COMPLETED = 'assignment_completed'.freeze
  EVENT_SKIPPED = 'assignment_skipped'.freeze
  def initialize(account:, inbox_id: nil, team_id: nil, limit: Ibsoft::ConversationDistribution::CandidateFinder::DEFAULT_LIMIT)
    @account = account
    @inbox_id = inbox_id
    @team_id = team_id
    @limit = limit
  end

  def perform
    preview = dry_run_preview.perform
    results = results_for(preview[:candidates])

    {
      generated_at: Time.current.iso8601,
      real_assignment_enabled: real_assignment_enabled?,
      filters: preview[:filters],
      limit: preview[:limit],
      summary: Ibsoft::ConversationDistribution::AssignmentSummaryBuilder.build(results),
      results: results
    }
  end

  private

  attr_reader :account, :inbox_id, :team_id, :limit

  def results_for(candidates)
    round_limiter = Ibsoft::ConversationDistribution::AssignmentRoundLimiter.new(candidates: candidates)

    candidates.map do |candidate|
      next process_candidate(candidate) if round_limiter.processable?(candidate)

      result_payload(candidate, 'ignored', 'round_limit_reached')
    end
  end

  def dry_run_preview
    @dry_run_preview ||= Ibsoft::ConversationDistribution::DryRunPreview.new(
      account: account,
      inbox_id: inbox_id,
      team_id: team_id,
      limit: limit
    )
  end

  def process_candidate(candidate)
    conversation = account.conversations.find(candidate[:conversation_id])
    decision = decision_for(conversation, candidate).perform
    return handle_non_assignment_decision(conversation, candidate, decision) unless decision[:action] == 'assign'
    return skipped_result(conversation, candidate, 'real_assignment_disabled', decision: decision) unless real_assignment_enabled?

    assign_candidate(conversation, candidate, decision)
  end

  def handle_non_assignment_decision(conversation, candidate, decision)
    handled_decision = decision_with_optional_action(conversation, candidate, decision)

    skipped_result(conversation, candidate, decision[:reason], decision: handled_decision)
  end

  def assign_candidate(conversation, candidate, decision)
    assignee = find_assignee(conversation, candidate)
    if assignee.blank?
      unavailable_decision = decision_for(conversation, candidate).unavailable_decision('no_available_agent')
      unavailable_decision = decision_with_optional_action(conversation, candidate, unavailable_decision)
      return skipped_result(conversation, candidate, 'no_available_agent', decision: unavailable_decision)
    end

    assignment = claim_and_assign(conversation, assignee)
    return skipped_result(conversation, candidate, 'candidate_already_claimed', decision: decision) if assignment.blank?

    notifications = post_assignment_actions(assignment, candidate, assignee)
    log_assignment_completed(assignment, candidate, assignee, decision, notifications)

    result_payload(candidate, 'assigned', 'assigned_to_agent', assignee, decision)
  end

  def post_assignment_actions(assignment, candidate, assignee)
    Ibsoft::ConversationDistribution::AssignmentRateTracker.track(
      account: account,
      conversation: assignment[:conversation],
      agent: assignee,
      policy: Ibsoft::ConversationDistribution::AssignmentPolicySnapshot.from_candidate(candidate)
    )
    {
      activity_message: activity_message_result(:assignment_completed, assignment[:conversation], assignee),
      assignment_confirmation: assignment_confirmation_result(assignment[:conversation], assignee)
    }
  end

  def log_assignment_completed(assignment, candidate, assignee, decision, notifications)
    log_event(
      conversation: assignment[:conversation],
      candidate: candidate,
      event_type: EVENT_COMPLETED,
      reason: 'assigned_to_agent',
      context: {
        decision: decision,
        assignment: {
          previous_assignee: assignment[:previous_assignee],
          new_assignee: assignee
        },
        assignment_confirmation: notifications[:assignment_confirmation],
        activity_message: notifications[:activity_message]
      }
    )
  end

  def activity_message_result(action, conversation, assignee)
    Ibsoft::ConversationDistribution::ActivityMessageNotifier.new(
      conversation: conversation,
      action: action,
      assignee: assignee
    ).perform
  end

  def assignment_confirmation_result(conversation, assignee)
    Ibsoft::ConversationDistribution::AssignmentConfirmationNotifier.new(
      conversation: conversation,
      assignee: assignee
    ).perform
  rescue StandardError => e
    Rails.logger.error("[Ibsoft::ConversationDistribution] assignment confirmation failed: #{e.class} - #{e.message}")
    { applied: false, status: 'error', error: e.class.name }
  end

  def find_assignee(conversation, candidate)
    allowed_agent_ids = allowed_agent_ids_for(conversation)
    return if allowed_agent_ids.blank?

    Ibsoft::ConversationDistribution::AssignmentAgentSelector.new(
      account: account,
      conversation: conversation,
      allowed_agent_ids: allowed_agent_ids,
      policy: Ibsoft::ConversationDistribution::AssignmentPolicySnapshot.from_candidate(candidate)
    ).perform
  end

  def allowed_agent_ids_for(conversation)
    return [] if conversation.team.blank?

    allowed_agent_ids = conversation.inbox.member_ids_with_assignment_capacity & conversation.team.members.ids
    Ibsoft::ConversationDistribution::AgentStabilizationFilter
      .new(account: account, allowed_agent_ids: allowed_agent_ids)
      .perform
  end

  def claim_and_assign(conversation, assignee)
    Conversation.transaction do
      locked_conversation = account.conversations
                                   .open
                                   .where(id: conversation.id, assignee_id: nil, first_reply_created_at: nil)
                                   .lock('FOR UPDATE SKIP LOCKED')
                                   .first
      next if locked_conversation.blank?

      previous_assignee = locked_conversation.assignee
      locked_conversation.update!(assignee: assignee)

      {
        conversation: locked_conversation,
        previous_assignee: previous_assignee
      }
    end
  end

  def skipped_result(conversation, candidate, reason, decision: nil)
    log_event(
      conversation: conversation,
      candidate: candidate,
      event_type: EVENT_SKIPPED,
      reason: reason,
      context: { decision: decision }
    )
    result_payload(candidate, 'skipped', reason, nil, decision)
  end

  def log_event(conversation:, candidate:, event_type:, reason:, context: {})
    metadata = {
      candidate: candidate,
      real_assignment_enabled: real_assignment_enabled?
    }
    decision = context[:decision]
    metadata[:decision] = decision if decision.present?
    metadata[:assignment_confirmation] = context[:assignment_confirmation] if context[:assignment_confirmation].present?
    metadata[:activity_message] = context[:activity_message] if context[:activity_message].present?

    event_logger.log(
      conversation: conversation,
      event_type: event_type,
      reason: reason,
      payload: {
        assignment: context[:assignment] || {},
        metadata: metadata,
        options: { dedupe: event_type == EVENT_SKIPPED }
      }
    )
  end

  def result_payload(candidate, status, reason, assignee = nil, decision = nil)
    {
      conversation_id: candidate[:conversation_id],
      display_id: candidate[:display_id],
      inbox_id: candidate[:inbox_id],
      team_id: candidate[:team_id],
      status: status,
      reason: reason,
      assignee_id: assignee&.id,
      assignee_name: assignee&.name,
      source: candidate[:source],
      policy: candidate[:policy]
    }.tap do |payload|
      payload[:decision] = decision if decision.present?
    end
  end

  def real_assignment_enabled? = Ibsoft::ConversationDistribution::ExecutionConfig.real_assignment_enabled?

  def decision_for(conversation, candidate)
    Ibsoft::ConversationDistribution::DecisionResolver.new(
      conversation: conversation,
      candidate: candidate
    )
  end

  def decision_with_optional_action(conversation, candidate, decision)
    return decision unless decision_action_effect?(decision)
    unless real_assignment_enabled?
      return decision.merge(action_applied: false, action_result: { applied: false, status: 'real_assignment_disabled' })
    end

    Ibsoft::ConversationDistribution::DecisionActionExecutor.new(
      conversation: conversation,
      decision: decision,
      candidate: candidate
    ).perform
  end

  def decision_action_effect?(decision)
    Ibsoft::ConversationDistribution::DecisionActionExecutor::ACTIONS_WITH_EFFECTS.include?(decision[:action])
  end

  def event_logger
    @event_logger ||= Ibsoft::ConversationDistribution::EventLogger.new(account: account)
  end
end
# rubocop:enable Metrics/ClassLength

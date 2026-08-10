class Ibsoft::ConversationDistribution::AgentAssignmentClaimer
  EVENT_COMPLETED = 'agent_claim_completed'.freeze
  EVENT_SKIPPED = 'agent_claim_skipped'.freeze
  REASON_COMPLETED = 'claimed_on_agent_entry'.freeze

  def initialize(account:, user:, conversation_ids:)
    @account = account
    @user = user
    @conversation_ids = Array(conversation_ids).compact_blank.map(&:to_i).uniq
    @policy_cache = {}
  end

  def perform
    results = claim_results

    {
      generated_at: Time.current.iso8601,
      real_assignment_enabled: Ibsoft::ConversationDistribution::ExecutionConfig.real_assignment_enabled?,
      summary: summary_payload(results),
      results: results
    }
  end

  private

  attr_reader :account, :user, :conversation_ids, :policy_cache

  def claim_results
    conversation_ids.map do |conversation_id|
      validation_reason = request_guard.reason_for(conversation_id)
      next skipped_prevalidated_result(conversation_id, validation_reason) if validation_reason.present?

      claim_conversation(conversation_id)
    end
  end

  def claim_conversation(conversation_id)
    conversation = account.conversations.includes(:inbox, :team).find_by(id: conversation_id)
    return skipped_payload(conversation_id, 'conversation_not_found') if conversation.blank?

    candidate = candidate_builder(conversation).payload_for(conversation)
    decision = Ibsoft::ConversationDistribution::DecisionResolver.new(
      conversation: conversation,
      candidate: candidate
    ).perform

    return skipped_result(conversation, candidate, 'not_available_for_agent', decision) unless agent_allowed_for?(conversation)
    return skipped_result(conversation, candidate, decision[:reason], decision) unless candidate[:eligible] && decision[:action] == 'assign'
    return skipped_result(conversation, candidate, 'real_assignment_disabled', decision) unless real_assignment_enabled?

    assignment = claim_and_assign(conversation)
    return skipped_result(conversation, candidate, 'candidate_already_claimed', decision) if assignment.blank?

    complete_assignment(assignment, candidate, decision)
  end

  def complete_assignment(assignment, candidate, decision)
    activity_message = activity_message_result(assignment[:conversation])
    log_completed(assignment, candidate, decision, activity_message)
    result_payload(assignment[:conversation], 'assigned', REASON_COMPLETED, decision)
  end

  def candidate_builder(conversation)
    Ibsoft::ConversationDistribution::AgentAssignmentCandidateBuilder.new(
      account: account,
      conversations: [conversation]
    )
  end

  def skipped_prevalidated_result(conversation_id, reason)
    candidate = request_guard.candidate_for(conversation_id)
    conversation = account.conversations.includes(:inbox, :team).find_by(id: conversation_id)
    return skipped_payload(conversation_id, reason) if conversation.blank? || candidate.blank?

    skipped_result(conversation, candidate, reason, candidate[:decision])
  end

  def request_guard
    @request_guard ||= Ibsoft::ConversationDistribution::AgentAssignmentRequestGuard.new(
      account: account,
      user: user,
      conversation_ids: conversation_ids
    )
  end

  def claim_and_assign(conversation)
    Conversation.transaction do
      locked_conversation = account.conversations
                                   .open
                                   .where(id: conversation.id, first_reply_created_at: nil)
                                   .unassigned
                                   .lock('FOR UPDATE SKIP LOCKED')
                                   .first
      next if locked_conversation.blank?

      previous_assignee = locked_conversation.assignee
      locked_conversation.update!(assignee: user)

      {
        conversation: locked_conversation,
        previous_assignee: previous_assignee
      }
    end
  end

  def agent_allowed_for?(conversation)
    current_account_user&.online? &&
      team_member?(conversation) &&
      inbox_member?(conversation)
  end

  def team_member?(conversation)
    conversation.team&.members&.exists?(user.id)
  end

  def inbox_member?(conversation)
    conversation.inbox&.members&.exists?(user.id)
  end

  def current_account_user
    @current_account_user ||= account.account_users.find_by(user_id: user.id)
  end

  def skipped_result(conversation, candidate, reason, decision = nil)
    log_skipped(conversation, candidate, reason, decision)
    result_payload(conversation, 'skipped', reason, decision)
  end

  def skipped_payload(conversation_id, reason)
    {
      conversation_id: conversation_id,
      status: 'skipped',
      reason: reason
    }
  end

  def result_payload(conversation, status, reason, decision)
    {
      conversation_id: conversation.id,
      display_id: conversation.display_id,
      status: status,
      reason: reason,
      assignee_id: conversation.assignee_id,
      assignee_name: conversation.assignee&.name,
      decision: decision
    }
  end

  def log_completed(assignment, candidate, decision, activity_message)
    event_logger.log(
      conversation: assignment[:conversation],
      event_type: EVENT_COMPLETED,
      reason: REASON_COMPLETED,
      payload: {
        assignment: {
          previous_assignee: assignment[:previous_assignee],
          new_assignee: user
        },
        metadata: {
          candidate: candidate,
          decision: decision,
          real_assignment_enabled: real_assignment_enabled?,
          activity_message: activity_message
        }
      }
    )
  end

  def activity_message_result(conversation)
    Ibsoft::ConversationDistribution::ActivityMessageNotifier.new(
      conversation: conversation,
      action: :agent_claim_completed,
      assignee: user
    ).perform
  end

  def log_skipped(conversation, candidate, reason, decision)
    event_logger.log(
      conversation: conversation,
      event_type: EVENT_SKIPPED,
      reason: reason,
      payload: {
        metadata: {
          candidate: candidate,
          decision: decision,
          real_assignment_enabled: real_assignment_enabled?
        }
      }
    )
  end

  def event_logger
    @event_logger ||= Ibsoft::ConversationDistribution::EventLogger.new(account: account)
  end

  def summary_payload(results)
    {
      requested: results.size,
      assigned: results.count { |result| result[:status] == 'assigned' },
      skipped: results.count { |result| result[:status] == 'skipped' },
      by_reason: results.group_by { |result| result[:reason] }.transform_values(&:size)
    }
  end

  def real_assignment_enabled?
    Ibsoft::ConversationDistribution::ExecutionConfig.real_assignment_enabled?
  end
end

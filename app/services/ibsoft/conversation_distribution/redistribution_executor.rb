class Ibsoft::ConversationDistribution::RedistributionExecutor
  EVENT_COMPLETED = 'redistribution_completed'.freeze
  EVENT_SKIPPED = 'redistribution_skipped'.freeze
  REASON_TIMEOUT = 'first_response_timeout'.freeze

  def initialize(account:, inbox_id: nil, team_id: nil, limit: Ibsoft::ConversationDistribution::RedistributionCandidateFinder::DEFAULT_LIMIT)
    @account = account
    @inbox_id = inbox_id
    @team_id = team_id
    @limit = limit
    @policy_cache = {}
  end

  def perform
    results = candidate_finder.perform.filter_map { |event| process_event(event) }

    {
      generated_at: Time.current.iso8601,
      real_assignment_enabled: real_assignment_enabled?,
      filters: filters_payload,
      limit: candidate_finder.safe_limit,
      summary: Ibsoft::ConversationDistribution::RedistributionResultBuilder.summary(results),
      results: results
    }
  end

  private

  attr_reader :account, :inbox_id, :team_id, :limit, :policy_cache

  def candidate_finder
    @candidate_finder ||= Ibsoft::ConversationDistribution::RedistributionCandidateFinder.new(
      account: account,
      inbox_id: inbox_id,
      team_id: team_id,
      limit: limit
    )
  end

  def process_event(event)
    conversation = event.conversation
    policy = Ibsoft::ConversationDistribution::RedistributionPolicy.new(effective_policy_for(conversation))

    return ignored_result(event, policy, 'policy_disabled') unless policy.enabled?
    return ignored_result(event, policy, 'redistribution_disabled') unless policy.redistribution_enabled?
    return ignored_result(event, policy, 'first_response_timeout_not_reached') unless first_response_timeout_reached?(event, policy)

    decision = decision_for(conversation).perform
    return skipped_result(event, policy, decision[:reason], decision: decision) unless decision[:action] == 'assign'
    return skipped_result(event, policy, 'real_assignment_disabled', decision: decision) unless real_assignment_enabled?

    redistribute_event(event, policy, decision)
  end

  def redistribute_event(event, policy, decision)
    conversation = event.conversation
    assignee = find_assignee(conversation, excluding_agent_id: event.new_assignee_id)

    return skipped_result(event, policy, 'no_available_agent', decision: decision) if assignee.blank?

    redistribution = claim_and_redistribute(conversation, event, assignee)
    return skipped_result(event, policy, 'candidate_already_changed', decision: decision) if redistribution.blank?

    log_event(
      event: event,
      conversation: redistribution[:conversation],
      policy: policy,
      event_type: EVENT_COMPLETED,
      reason: REASON_TIMEOUT,
      assignment: {
        previous_assignee: redistribution[:previous_assignee],
        new_assignee: assignee
      },
      decision: decision
    )

    result_payload(event, policy, status: 'redistributed', reason: REASON_TIMEOUT, assignee: assignee, decision: decision)
  end

  def find_assignee(conversation, excluding_agent_id:)
    allowed_agent_ids = allowed_agent_ids_for(conversation) - [excluding_agent_id]
    return if allowed_agent_ids.blank?

    AutoAssignment::AgentAssignmentService.new(
      conversation: conversation,
      allowed_agent_ids: allowed_agent_ids
    ).find_assignee
  end

  def allowed_agent_ids_for(conversation)
    return [] if conversation.team.blank?
    return [] if conversation.team.allow_auto_assign.blank?

    conversation.inbox.member_ids_with_assignment_capacity & conversation.team.members.ids
  end

  def claim_and_redistribute(conversation, event, assignee)
    Conversation.transaction do
      locked_conversation = account.conversations
                                   .open
                                   .where(id: conversation.id, assignee_id: event.new_assignee_id, first_reply_created_at: nil)
                                   .lock('FOR UPDATE SKIP LOCKED')
                                   .first
      next if locked_conversation.blank?
      next unless latest_distribution_event_for(locked_conversation)&.id == event.id

      previous_assignee = locked_conversation.assignee
      locked_conversation.update!(assignee: assignee)

      {
        conversation: locked_conversation,
        previous_assignee: previous_assignee
      }
    end
  end

  def latest_distribution_event_for(conversation)
    Ibsoft::ConversationDistribution::EventLog
      .where(
        account: account,
        conversation: conversation,
        event_type: Ibsoft::ConversationDistribution::RedistributionCandidateFinder::REDISTRIBUTABLE_EVENT_TYPES
      )
      .order(created_at: :desc, id: :desc)
      .first
  end

  def skipped_result(event, policy, reason, decision: nil)
    log_event(
      event: event,
      conversation: event.conversation,
      policy: policy,
      event_type: EVENT_SKIPPED,
      reason: reason,
      decision: decision
    )

    result_payload(event, policy, status: 'skipped', reason: reason, decision: decision)
  end

  def ignored_result(event, policy, reason)
    result_payload(event, policy, status: 'ignored', reason: reason)
  end

  def log_event(context)
    event = context[:event]
    policy = context[:policy]
    metadata = {
      trigger_event_id: event.id,
      trigger_event_type: event.event_type,
      trigger_event_created_at: event.created_at.iso8601,
      waited_seconds: (Time.current - event.created_at).to_i,
      timeout_minutes: policy.timeout_minutes,
      real_assignment_enabled: real_assignment_enabled?
    }
    metadata[:decision] = context[:decision] if context[:decision].present?

    event_logger.log(
      conversation: context[:conversation],
      event_type: context[:event_type],
      reason: context[:reason],
      assignment: context[:assignment] || {},
      metadata: metadata
    )
  end

  def result_payload(event, policy, outcome)
    Ibsoft::ConversationDistribution::RedistributionResultBuilder.build(event: event, policy: policy, outcome: outcome)
  end

  def effective_policy_for(conversation)
    cache_key = [conversation.inbox_id, conversation.team_id]
    policy_cache[cache_key] ||= Ibsoft::ConversationDistribution::EffectivePolicyResolver.new(
      account: account,
      inbox: conversation.inbox,
      team: conversation.team
    ).perform
  end

  def decision_for(conversation)
    Ibsoft::ConversationDistribution::DecisionResolver.new(
      conversation: conversation,
      candidate: { eligible: true, reasons: [] }
    )
  end

  def first_response_timeout_reached?(event, policy)
    event.created_at <= policy.timeout_minutes.minutes.ago
  end

  def filters_payload
    {
      inbox_id: inbox_id.presence,
      team_id: team_id.presence
    }
  end

  def real_assignment_enabled?
    Ibsoft::ConversationDistribution::ExecutionConfig.real_assignment_enabled?
  end

  def event_logger
    @event_logger ||= Ibsoft::ConversationDistribution::EventLogger.new(account: account)
  end
end

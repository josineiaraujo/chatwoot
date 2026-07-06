class Ibsoft::ConversationDistribution::DryRunPreview
  def initialize(account:, inbox_id: nil, team_id: nil, limit: Ibsoft::ConversationDistribution::CandidateFinder::DEFAULT_LIMIT)
    @account = account
    @inbox_id = inbox_id
    @team_id = team_id
    @limit = limit
    @policy_cache = {}
  end

  def perform
    conversations = candidate_finder.perform.to_a
    evaluated_candidates = evaluate_conversations(conversations)
    prioritized_candidates = Ibsoft::ConversationDistribution::CandidatePrioritizer.new(
      candidates: evaluated_candidates
    ).perform.first(safe_limit)

    {
      generated_at: Time.current.iso8601,
      filters: filters_payload,
      limit: safe_limit,
      summary: summary_payload(prioritized_candidates),
      candidates: prioritized_candidates
    }
  end

  private

  attr_reader :account, :inbox_id, :team_id, :limit, :policy_cache

  def candidate_finder
    @candidate_finder ||= Ibsoft::ConversationDistribution::CandidateFinder.new(
      account: account,
      inbox_id: inbox_id,
      team_id: team_id,
      limit: Ibsoft::ConversationDistribution::CandidateFinder::MAX_LIMIT
    )
  end

  def safe_limit
    requested_limit = limit.to_i
    requested_limit = Ibsoft::ConversationDistribution::CandidateFinder::DEFAULT_LIMIT unless requested_limit.positive?

    [requested_limit, Ibsoft::ConversationDistribution::CandidateFinder::MAX_LIMIT].min
  end

  def evaluate_conversations(conversations)
    handoff_ids = bot_handoff_conversation_ids(conversations)

    conversations.map do |conversation|
      source = Ibsoft::ConversationDistribution::SourceResolver.new(
        conversation: conversation,
        bot_handoff: handoff_ids.include?(conversation.id)
      ).perform
      policy = effective_policy_for(conversation)
      eligibility = Ibsoft::ConversationDistribution::CandidateEvaluator.new(
        conversation: conversation,
        policy: policy,
        source: source
      ).perform

      candidate_payload(conversation, source, policy, eligibility)
    end
  end

  def bot_handoff_conversation_ids(conversations)
    conversation_ids = conversations.map(&:id)
    return [] if conversation_ids.blank?

    account.reporting_events
           .where(name: 'conversation_bot_handoff', conversation_id: conversation_ids)
           .pluck(:conversation_id)
  end

  def effective_policy_for(conversation)
    cache_key = [conversation.inbox_id, conversation.team_id]
    policy_cache[cache_key] ||= Ibsoft::ConversationDistribution::EffectivePolicyResolver.new(
      account: account,
      inbox: conversation.inbox,
      team: conversation.team
    ).perform
  end

  def candidate_payload(conversation, source, policy, eligibility)
    {
      conversation_id: conversation.id,
      display_id: conversation.display_id,
      inbox_id: conversation.inbox_id,
      inbox_name: conversation.inbox.name,
      team_id: conversation.team_id,
      team_name: conversation.team&.name,
      status: conversation.status,
      created_at: conversation.created_at&.iso8601,
      waiting_since: conversation.waiting_since&.iso8601,
      last_activity_at: conversation.last_activity_at&.iso8601,
      first_reply_created_at: conversation.first_reply_created_at&.iso8601,
      source: source[:source],
      source_confidence: source[:confidence],
      eligible: eligibility[:eligible],
      reasons: eligibility[:reasons],
      policy: policy_payload(policy)
    }
  end

  def policy_payload(policy)
    {
      id: policy[:id],
      source: policy[:source],
      policy_type: policy[:policy_type],
      enabled: policy[:enabled],
      eligible_sources: Array(policy.dig(:config, 'eligible_sources')),
      unavailable_action: unavailability_action(policy, 'no_available_agent'),
      no_available_agent_action: unavailability_action(policy, 'no_available_agent'),
      outside_business_hours_action: unavailability_action(policy, 'outside_business_hours'),
      business_hours_mode: policy.dig(:config, 'business_hours', 'mode')
    }.merge(distribution_policy_payload(policy))
  end

  def unavailability_action(policy, reason)
    Ibsoft::ConversationDistribution::UnavailabilityConfig.for(policy[:config], reason)['action']
  end

  def distribution_policy_payload(policy)
    distribution = policy.dig(:config, 'distribution') || {}

    {
      max_assignments_per_round_enabled: distribution['max_assignments_per_round_enabled'],
      max_assignments_per_round: distribution['max_assignments_per_round'],
      assignment_order: distribution['assignment_order'],
      conversation_priority: distribution['conversation_priority'],
      assignment_limit_mode: distribution['assignment_limit_mode'],
      open_conversation_limit: distribution['open_conversation_limit'],
      capacity_ignore_customer_waiting_enabled: distribution['capacity_ignore_customer_waiting_enabled'],
      capacity_ignore_customer_waiting_minutes: distribution['capacity_ignore_customer_waiting_minutes'],
      capacity_excluded_labels: Array(distribution['capacity_excluded_labels']),
      fair_distribution_limit: distribution['fair_distribution_limit'],
      fair_distribution_window: distribution['fair_distribution_window']
    }
  end

  def summary_payload(candidates)
    reasons = candidates.flat_map { |candidate| candidate[:reasons] }
    {
      scanned: candidates.length,
      eligible: candidates.count { |candidate| candidate[:eligible] },
      ineligible: candidates.count { |candidate| !candidate[:eligible] },
      by_source: candidates.group_by { |candidate| candidate[:source] || 'unknown' }.transform_values(&:count),
      by_reason: reasons.tally
    }
  end

  def filters_payload
    {
      inbox_id: inbox_id.presence,
      team_id: team_id.presence
    }
  end
end

class Ibsoft::ConversationDistribution::AgentAssignmentCandidateBuilder
  def initialize(account:, conversations:)
    @account = account
    @conversations = Array(conversations)
    @policy_cache = {}
  end

  def payload_for(conversation)
    source = source_for(conversation)
    policy = effective_policy_for(conversation)
    eligibility = Ibsoft::ConversationDistribution::CandidateEvaluator.new(
      conversation: conversation,
      policy: policy,
      source: source
    ).perform

    base_payload(conversation, source, eligibility).merge(
      policy: policy_payload(policy)
    )
  end

  private

  attr_reader :account, :conversations, :policy_cache

  def base_payload(conversation, source, eligibility)
    {
      conversation_id: conversation.id,
      display_id: conversation.display_id,
      inbox_id: conversation.inbox_id,
      inbox_name: conversation.inbox.name,
      team_id: conversation.team_id,
      team_name: conversation.team&.name,
      contact: contact_payload(conversation.contact),
      waiting_since: conversation.waiting_since&.iso8601,
      last_activity_at: conversation.last_activity_at&.iso8601,
      minutes_waiting: minutes_waiting(conversation),
      source: source[:source],
      source_confidence: source[:confidence],
      eligible: eligibility[:eligible],
      reasons: eligibility[:reasons]
    }
  end

  def source_for(conversation)
    Ibsoft::ConversationDistribution::SourceResolver.new(
      conversation: conversation,
      bot_handoff: bot_handoff_conversation_ids.include?(conversation.id)
    ).perform
  end

  def bot_handoff_conversation_ids
    @bot_handoff_conversation_ids ||= begin
      ids = conversations.map(&:id)
      ids.present? ? reporting_event_conversation_ids(ids) : []
    end
  end

  def reporting_event_conversation_ids(ids)
    account.reporting_events
           .where(name: 'conversation_bot_handoff', conversation_id: ids)
           .pluck(:conversation_id)
  end

  def effective_policy_for(conversation)
    policy_cache[[conversation.inbox_id, conversation.team_id]] ||= Ibsoft::ConversationDistribution::EffectivePolicyResolver.new(
      account: account,
      inbox: conversation.inbox,
      team: conversation.team
    ).perform
  end

  def policy_payload(policy)
    {
      id: policy[:id],
      source: policy[:source],
      policy_type: policy[:policy_type],
      enabled: policy[:enabled],
      business_hours_mode: policy.dig(:config, 'business_hours', 'mode'),
      assignment_limit_mode: policy.dig(:config, 'distribution', 'assignment_limit_mode'),
      open_conversation_limit: policy.dig(:config, 'distribution', 'open_conversation_limit'),
      capacity_ignore_customer_waiting_enabled: policy.dig(:config, 'distribution', 'capacity_ignore_customer_waiting_enabled'),
      capacity_ignore_customer_waiting_minutes: policy.dig(:config, 'distribution', 'capacity_ignore_customer_waiting_minutes'),
      capacity_excluded_labels: Array(policy.dig(:config, 'distribution', 'capacity_excluded_labels')),
      max_assignments_per_round: policy.dig(:config, 'distribution', 'max_assignments_per_round')
    }
  end

  def contact_payload(contact)
    return if contact.blank?

    {
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone_number: contact.phone_number
    }
  end

  def minutes_waiting(conversation)
    return 0 if conversation.waiting_since.blank?

    ((Time.current - conversation.waiting_since) / 60).floor
  end
end

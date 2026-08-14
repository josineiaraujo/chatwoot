class Ibsoft::ConversationDistribution::AutomationHandoffCandidateFinder
  DEFAULT_LIMIT = Ibsoft::ConversationDistribution::CandidateFinder::DEFAULT_LIMIT
  MAX_LIMIT = Ibsoft::ConversationDistribution::CandidateFinder::MAX_LIMIT
  COMPLETED_EVENT_TYPES = %w[
    automation_handoff_completed
    automation_close_completed
    automation_close_warning_sent
  ].freeze
  LAST_PUBLIC_MESSAGE_JOIN = <<~SQL.squish.freeze
    INNER JOIN LATERAL (
      SELECT messages.id, messages.created_at, messages.sender_type, messages.message_type
      FROM messages
      WHERE messages.conversation_id = conversations.id
        AND messages.account_id = conversations.account_id
        AND messages.private = FALSE
        AND messages.message_type <> #{Message.message_types.fetch('activity')}
      ORDER BY messages.created_at DESC, messages.id DESC
      LIMIT 1
    ) ibsoft_automation_last_message ON TRUE
  SQL

  def initialize(account:, inbox_id: nil, limit: DEFAULT_LIMIT)
    @account = account
    @inbox_id = inbox_id
    @limit = limit
  end

  def perform
    policies.each_with_object([]) do |policy, candidates|
      break candidates if candidates.length >= safe_limit

      candidates.concat(candidates_for_policy(policy, safe_limit - candidates.length))
    end
  end

  def safe_limit
    requested_limit = limit.to_i
    requested_limit = DEFAULT_LIMIT unless requested_limit.positive?

    [requested_limit, MAX_LIMIT].min
  end

  private

  attr_reader :account, :inbox_id, :limit

  def policies
    @policies ||= begin
      scope = Ibsoft::ConversationDistribution::AutomationHandoffPolicy
              .enabled
              .includes(:inbox, :target_team)
              .where(account: account)
              .order(:inbox_id)
      scope = scope.where(inbox_id: inbox_id) if inbox_id.present?
      scope.to_a
    end
  end

  def candidates_for_policy(policy, remaining_limit)
    eligible_conversations(policy)
      .limit(remaining_limit)
      .filter_map { |conversation| candidate_payload(policy, conversation) }
  end

  def eligible_conversations(policy)
    eligible_scope(policy)
      .select(
        'conversations.*',
        'ibsoft_automation_last_message.id AS automation_last_message_id',
        'ibsoft_automation_last_message.created_at AS automation_last_message_at',
        'ibsoft_automation_last_message.sender_type AS automation_last_sender_type'
      )
      .order(Arel.sql('ibsoft_automation_last_message.created_at ASC, conversations.id ASC'))
  end

  def eligible_scope(policy)
    account.conversations
           .joins(LAST_PUBLIC_MESSAGE_JOIN)
           .includes(:inbox, :team, :assignee_agent_bot)
           .pending
           .where(assignee_id: nil, inbox_id: policy.inbox_id, first_reply_created_at: nil)
           .where.not(id: active_close_schedule_conversation_ids)
           .where(ibsoft_automation_last_message: automation_message_conditions)
           .where('ibsoft_automation_last_message.created_at <= ?', policy.stale_after_minutes.minutes.ago)
  end

  def active_close_schedule_conversation_ids
    Ibsoft::ConversationDistribution::AutomationCloseSchedule
      .where(account: account)
      .select(:conversation_id)
  end

  def automation_message_conditions
    {
      message_type: Message.message_types.fetch('outgoing'),
      sender_type: Ibsoft::ConversationDistribution::AutomationWaitingSignal::BOT_SENDER_TYPES
    }
  end

  def candidate_payload(policy, conversation)
    return if already_processed_after_last_bot_message?(conversation)

    last_bot_message_at = automation_last_message_at(conversation)
    return if last_bot_message_at.blank?

    candidate_identity(conversation).merge(
      candidate_routing(policy, conversation),
      candidate_waiting(conversation, last_bot_message_at)
    )
  end

  def candidate_identity(conversation)
    {
      conversation_id: conversation.id,
      display_id: conversation.display_id,
      inbox_id: conversation.inbox_id,
      inbox_name: conversation.inbox.name
    }
  end

  def candidate_routing(policy, conversation)
    {
      previous_team_id: conversation.team_id,
      previous_team_name: conversation.team&.name,
      target_team_id: policy.target_team_id,
      target_team_name: policy.target_team&.name,
      policy_id: policy.id,
      stale_after_minutes: policy.stale_after_minutes,
      timeout_action: policy.timeout_action
    }
  end

  def candidate_waiting(conversation, last_bot_message_at)
    {
      last_bot_message_id: conversation.read_attribute(:automation_last_message_id),
      last_bot_message_at: last_bot_message_at&.iso8601,
      last_activity_at: conversation.last_activity_at&.iso8601,
      waited_seconds: (Time.current - last_bot_message_at).to_i,
      automation_signal: automation_signal_reason(conversation)
    }
  end

  def automation_signal_reason(conversation)
    return 'active_inbox_bot' if conversation.inbox.active_bot?
    return 'assigned_agent_bot' if conversation.assignee_agent_bot_id.present?

    conversation.read_attribute(:automation_last_sender_type) == 'Captain::Assistant' ? 'captain_assistant_message' : 'agent_bot_message'
  end

  def already_processed_after_last_bot_message?(conversation)
    last_message_at = automation_last_message_at(conversation)
    return false if last_message_at.blank?

    Ibsoft::ConversationDistribution::EventLog
      .where(
        account: account,
        conversation: conversation,
        event_type: COMPLETED_EVENT_TYPES
      )
      .exists?(created_at: last_message_at..)
  end

  def automation_last_message_at(conversation)
    value = conversation.read_attribute(:automation_last_message_at)
    return value if value.respond_to?(:in_time_zone)
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end

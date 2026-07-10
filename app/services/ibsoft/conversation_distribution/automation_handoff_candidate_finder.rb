class Ibsoft::ConversationDistribution::AutomationHandoffCandidateFinder
  DEFAULT_LIMIT = Ibsoft::ConversationDistribution::CandidateFinder::DEFAULT_LIMIT
  MAX_LIMIT = Ibsoft::ConversationDistribution::CandidateFinder::MAX_LIMIT

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
              .where.not(target_team_id: nil)
              .order(:inbox_id)
      scope = scope.where(inbox_id: inbox_id) if inbox_id.present?
      scope.to_a
    end
  end

  def candidates_for_policy(policy, remaining_limit)
    eligible_conversations(policy)
      .limit(remaining_limit)
      .filter_map { |conversation| candidate_payload(policy, conversation) if automation_signal?(conversation) }
  end

  def eligible_conversations(policy)
    account.conversations
           .includes(:inbox, :team, :assignee_agent_bot)
           .pending
           .unassigned
           .where(inbox_id: policy.inbox_id, first_reply_created_at: nil)
           .where('last_activity_at <= ?', policy.stale_after_minutes.minutes.ago)
           .order(last_activity_at: :asc, id: :asc)
  end

  def candidate_payload(policy, conversation)
    return if already_handoffed_after_last_activity?(conversation)

    {
      conversation_id: conversation.id,
      display_id: conversation.display_id,
      inbox_id: conversation.inbox_id,
      inbox_name: conversation.inbox.name,
      previous_team_id: conversation.team_id,
      previous_team_name: conversation.team&.name,
      target_team_id: policy.target_team_id,
      target_team_name: policy.target_team&.name,
      policy_id: policy.id,
      stale_after_minutes: policy.stale_after_minutes,
      last_activity_at: conversation.last_activity_at&.iso8601,
      waited_seconds: (Time.current - conversation.last_activity_at).to_i,
      automation_signal: automation_signal_reason(conversation)
    }
  end

  def automation_signal?(conversation)
    automation_signal_reason(conversation).present?
  end

  def automation_signal_reason(conversation)
    return 'active_inbox_bot' if conversation.inbox.active_bot?
    return 'assigned_agent_bot' if conversation.assignee_agent_bot_id.present?
    return 'agent_bot_message' if agent_bot_message?(conversation)
  end

  def agent_bot_message?(conversation)
    conversation.messages.exists?(sender_type: 'AgentBot')
  end

  def already_handoffed_after_last_activity?(conversation)
    Ibsoft::ConversationDistribution::EventLog
      .where(
        account: account,
        conversation: conversation,
        event_type: Ibsoft::ConversationDistribution::AutomationHandoffExecutor::EVENT_COMPLETED
      )
      .exists?(created_at: conversation.last_activity_at..)
  end
end

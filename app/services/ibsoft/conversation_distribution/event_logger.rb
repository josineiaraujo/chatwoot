class Ibsoft::ConversationDistribution::EventLogger
  def initialize(account:)
    @account = account
  end

  def log(conversation:, event_type:, reason:, payload: {})
    duplicate_event = duplicate_event_for(conversation, event_type, reason, payload)
    return duplicate_event if duplicate_event.present?

    create_event(conversation, event_type, reason, payload)
  end

  private

  attr_reader :account

  def create_event(conversation, event_type, reason, payload)
    assignment = payload.fetch(:assignment, {})

    Ibsoft::ConversationDistribution::EventLog.create!(
      account: account,
      conversation: conversation,
      inbox: conversation&.inbox,
      team: conversation&.team,
      previous_assignee: assignment[:previous_assignee],
      new_assignee: assignment[:new_assignee],
      event_type: event_type,
      reason: reason,
      metadata: payload.fetch(:metadata, {})
    )
  end

  def duplicate_event_for(conversation, event_type, reason, payload)
    return unless payload.fetch(:options, {})[:dedupe]

    recent_duplicate_event(
      conversation: conversation,
      event_type: event_type,
      reason: reason
    )
  end

  def recent_duplicate_event(conversation:, event_type:, reason:)
    dedupe_window = Ibsoft::ConversationDistribution::ExecutionConfig.event_dedupe_window
    return if dedupe_window.to_i.zero?

    Ibsoft::ConversationDistribution::EventLog
      .where(
        account: account,
        conversation_id: conversation&.id,
        event_type: event_type,
        reason: reason
      )
      .where(created_at: dedupe_window.ago..)
      .order(created_at: :desc, id: :desc)
      .first
  end
end

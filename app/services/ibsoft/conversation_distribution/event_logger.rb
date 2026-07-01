class Ibsoft::ConversationDistribution::EventLogger
  def initialize(account:)
    @account = account
  end

  def log(conversation:, event_type:, reason:, assignment: {}, metadata: {})
    Ibsoft::ConversationDistribution::EventLog.create!(
      account: account,
      conversation: conversation,
      inbox: conversation&.inbox,
      team: conversation&.team,
      previous_assignee: assignment[:previous_assignee],
      new_assignee: assignment[:new_assignee],
      event_type: event_type,
      reason: reason,
      metadata: metadata
    )
  end

  private

  attr_reader :account
end

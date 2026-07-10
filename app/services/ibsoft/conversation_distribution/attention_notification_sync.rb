class Ibsoft::ConversationDistribution::AttentionNotificationSync
  STALE_ASSIGNEE_NOTIFICATION_TYPES = %w[
    conversation_assignment
    assigned_conversation_new_message
    participating_conversation_new_message
  ].freeze

  def initialize(account:, conversation:, previous_assignee:, new_assignee: nil)
    @account = account
    @conversation = conversation
    @previous_assignee = previous_assignee
    @new_assignee = new_assignee
  end

  def perform
    return empty_result if previous_assignee.blank?
    return empty_result if previous_assignee.id == new_assignee&.id

    removed_count = stale_notifications_count
    stale_notifications.find_each(&:destroy!)

    { removed_count: removed_count }
  rescue StandardError => e
    Rails.logger.warn(
      '[Ibsoft::ConversationDistribution] attention notification sync failed ' \
      "conversation=#{conversation&.id} previous_assignee=#{previous_assignee&.id} error=#{e.class}: #{e.message}"
    )

    empty_result.merge(error: e.class.name)
  end

  private

  attr_reader :account, :conversation, :previous_assignee, :new_assignee

  def stale_notifications
    @stale_notifications ||= Notification.where(
      account: account,
      user: previous_assignee,
      primary_actor: conversation,
      notification_type: STALE_ASSIGNEE_NOTIFICATION_TYPES
    )
  end

  def stale_notifications_count
    @stale_notifications_count ||= stale_notifications.count
  end

  def empty_result
    { removed_count: 0 }
  end
end

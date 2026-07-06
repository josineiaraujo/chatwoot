class Ibsoft::Conversation::ResolvedAttentionNotificationCleanup
  def initialize(conversation:)
    @conversation = conversation
  end

  def perform
    return empty_result if conversation.blank?

    removed_count = notifications.count
    notifications.find_each(&:destroy!)

    { removed_count: removed_count }
  rescue StandardError => e
    Rails.logger.warn(
      '[Ibsoft::Conversation] resolved attention notification cleanup failed ' \
      "conversation=#{conversation&.id} error=#{e.class}: #{e.message}"
    )

    empty_result.merge(error: e.class.name)
  end

  private

  attr_reader :conversation

  def notifications
    @notifications ||= Notification.where(
      account_id: conversation.account_id,
      primary_actor: conversation
    )
  end

  def empty_result
    { removed_count: 0 }
  end
end

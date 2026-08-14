class Ibsoft::ConversationDistribution::AutomationWaitingSignal
  BOT_SENDER_TYPES = ['AgentBot', 'Captain::Assistant'].freeze

  def initialize(conversation:, stale_after_minutes:, expected_message_id: nil)
    @conversation = conversation
    @stale_after_minutes = stale_after_minutes
    @expected_message_id = expected_message_id
  end

  def eligible?
    return false if message.blank?
    return false if expected_message_id.present? && message.id != expected_message_id.to_i

    message.outgoing? && message.sender_type.in?(BOT_SENDER_TYPES) && message.created_at <= stale_threshold
  end

  def message
    @message ||= conversation.messages.chat.reorder(created_at: :desc, id: :desc).first
  end

  private

  attr_reader :conversation, :stale_after_minutes, :expected_message_id

  def stale_threshold
    stale_after_minutes.to_i.minutes.ago
  end
end

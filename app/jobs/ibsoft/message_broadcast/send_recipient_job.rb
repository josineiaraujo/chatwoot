class Ibsoft::MessageBroadcast::SendRecipientJob < ApplicationJob
  queue_as :medium

  def perform(recipient_id)
    recipient = Ibsoft::MessageBroadcast::Recipient.find_by(id: recipient_id)
    return if recipient.blank?

    result = Ibsoft::MessageBroadcast::RecipientSender.new(
      broadcast: recipient.broadcast,
      recipient: recipient
    ).call
    return reschedule(recipient) if result == Ibsoft::MessageBroadcast::RecipientSender::RESULT_RATE_LIMITED

    finalize(recipient.broadcast)
  rescue StandardError
    finalize(recipient.broadcast) if recipient
    raise
  end

  private

  def reschedule(recipient)
    self.class.set(wait: 1.second).perform_later(recipient.id)
  end

  def finalize(broadcast)
    Ibsoft::MessageBroadcast::BroadcastFinalizer.new(broadcast: broadcast).call
  end
end

class Ibsoft::MessageBroadcast::BroadcastSender
  def initialize(broadcast:)
    @broadcast = broadcast
  end

  def call
    return false unless execution_claim.acquire

    broadcast.single_dispatch? ? deliver_single : enqueue_bulk
    true
  rescue StandardError
    fail_single_broadcast! if broadcast.persisted? && broadcast.single_dispatch?
    raise
  end

  private

  attr_reader :broadcast

  def deliver_single
    recipient = broadcast.recipients.where(status: %w[pending queued]).order(:id).first
    Ibsoft::MessageBroadcast::RecipientSender.new(broadcast: broadcast, recipient: recipient).call if recipient
    Ibsoft::MessageBroadcast::BroadcastFinalizer.new(broadcast: broadcast).call
  end

  def enqueue_bulk
    broadcast.recipients.where(status: 'queued').order(:id).pluck(:id).each do |recipient_id|
      enqueue_recipient(recipient_id)
    end
    Ibsoft::MessageBroadcast::BroadcastFinalizer.new(broadcast: broadcast).call
  end

  def enqueue_recipient(recipient_id)
    Ibsoft::MessageBroadcast::SendRecipientJob.perform_later(recipient_id)
    now = Time.current
    # rubocop:disable Rails/SkipsModelValidations
    Ibsoft::MessageBroadcast::Recipient
      .where(id: recipient_id, status: 'queued')
      .update_all(enqueued_at: now, updated_at: now)
    # rubocop:enable Rails/SkipsModelValidations
  rescue StandardError => e
    Rails.logger.error(
      "[Ibsoft::MessageBroadcast] enqueue failed recipient=#{recipient_id} error=#{e.class}"
    )
  end

  def fail_single_broadcast!
    # rubocop:disable Rails/SkipsModelValidations
    Ibsoft::MessageBroadcast::Broadcast
      .where(id: broadcast.id, status: 'running')
      .update_all(status: 'failed', finished_at: Time.current, updated_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def execution_claim
    @execution_claim ||= Ibsoft::MessageBroadcast::BroadcastExecutionClaim.new(broadcast: broadcast)
  end
end

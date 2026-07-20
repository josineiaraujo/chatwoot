class Ibsoft::MessageBroadcast::BroadcastSender
  def initialize(broadcast:)
    @broadcast = broadcast
  end

  def call
    return unless execution_claim.acquire

    deliverable_recipients.find_each do |recipient|
      Ibsoft::MessageBroadcast::RecipientSender.new(
        broadcast: broadcast,
        recipient: recipient
      ).call
    end
    finish_broadcast!
  rescue StandardError
    fail_broadcast! if broadcast.persisted?
    raise
  end

  private

  attr_reader :broadcast

  def deliverable_recipients
    broadcast.recipients.where(status: %w[pending queued])
  end

  def finish_broadcast!
    status = broadcast.recipients.exists?(status: %w[pending queued processing failed]) ? 'failed' : 'completed'
    broadcast.update!(status: status, finished_at: Time.current)
  end

  def fail_broadcast!
    # Preserve a terminal state written by another execution.
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

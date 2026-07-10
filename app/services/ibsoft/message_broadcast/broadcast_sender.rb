class Ibsoft::MessageBroadcast::BroadcastSender
  def initialize(broadcast:)
    @broadcast = broadcast
  end

  def call
    return unless broadcast.status.in?(%w[queued running])

    broadcast.update!(status: 'running', started_at: Time.current)
    deliverable_recipients.find_each do |recipient|
      Ibsoft::MessageBroadcast::RecipientSender.new(
        broadcast: broadcast,
        recipient: recipient
      ).call
    end
    finish_broadcast!
  rescue StandardError
    broadcast.update!(status: 'failed', finished_at: Time.current)
    raise
  end

  private

  attr_reader :broadcast

  def deliverable_recipients
    broadcast.recipients.where(status: %w[pending queued])
  end

  def finish_broadcast!
    status = broadcast.recipients.exists?(status: %w[pending queued failed]) ? 'failed' : 'completed'
    broadcast.update!(status: status, finished_at: Time.current)
  end
end

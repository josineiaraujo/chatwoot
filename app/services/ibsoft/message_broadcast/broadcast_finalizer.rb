class Ibsoft::MessageBroadcast::BroadcastFinalizer
  ACTIVE_RECIPIENT_STATUSES = %w[pending queued processing].freeze
  FAILED_RECIPIENT_STATUSES = %w[failed uncertain].freeze

  def initialize(broadcast:)
    @broadcast = broadcast
  end

  def call
    return false if broadcast.status.in?(%w[draft cancelled])
    return false if recipients.exists?(status: ACTIVE_RECIPIENT_STATUSES)

    next_status = recipients.exists?(status: FAILED_RECIPIENT_STATUSES) ? 'failed' : 'completed'
    return false if broadcast.status == next_status && broadcast.finished_at.present?

    broadcast.update!(
      status: next_status,
      finished_at: broadcast.finished_at || Time.current
    )
    true
  end

  private

  attr_reader :broadcast

  def recipients
    broadcast.recipients
  end
end

class Ibsoft::MessageBroadcast::StatusUpdater
  STATUS_ORDER = {
    'accepted' => 0,
    'sent' => 1,
    'delivered' => 2,
    'read' => 3
  }.freeze

  def initialize(recipient:, status:)
    @recipient = recipient
    @status = status.to_h.with_indifferent_access
  end

  def call
    update_recipient
    Ibsoft::MessageBroadcast::BroadcastFinalizer.new(broadcast: recipient.broadcast).call
  end

  private

  attr_reader :recipient, :status

  def update_recipient
    return mark_failed if status[:status] == 'failed'
    return unless STATUS_ORDER.key?(status[:status])
    return if terminal_or_newer_status?

    recipient.update!(status: status[:status], error_code: nil, error_message: nil)
  end

  def terminal_or_newer_status?
    return true if recipient.status.in?(%w[failed uncertain skipped])

    STATUS_ORDER.fetch(recipient.status, -1) >= STATUS_ORDER.fetch(status[:status])
  end

  def mark_failed
    error = Array(status[:errors]).first.to_h.with_indifferent_access
    recipient.update!(
      status: 'failed',
      error_code: error[:code].presence&.to_s || 'meta_delivery_failed',
      error_message: error[:title].presence || error[:message]
    )
  end
end

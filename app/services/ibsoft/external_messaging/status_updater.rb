class Ibsoft::ExternalMessaging::StatusUpdater
  STATUS_ORDER = {
    'accepted' => 0,
    'sent' => 1,
    'delivered' => 2,
    'read' => 3
  }.freeze

  def initialize(status:, delivery: nil, trackable: nil)
    @delivery = trackable || delivery
    @status = status.to_h.with_indifferent_access
  end

  def call
    return mark_failed if status[:status] == 'failed'
    return unless STATUS_ORDER.key?(status[:status])
    return if terminal_or_newer_status?

    delivery.update!(status: status[:status], **timestamps)
  end

  private

  attr_reader :delivery, :status

  def terminal_or_newer_status?
    return true if delivery.status.in?(%w[failed uncertain])

    STATUS_ORDER.fetch(delivery.status, -1) >= STATUS_ORDER.fetch(status[:status])
  end

  def timestamps
    case status[:status]
    when 'delivered' then { delivered_at: Time.current }
    when 'read' then { delivered_at: delivery.delivered_at || Time.current, read_at: Time.current }
    else {}
    end
  end

  def mark_failed
    error = Array(status[:errors]).first.to_h.with_indifferent_access
    delivery.update!(
      status: 'failed',
      error_code: error[:code].presence&.to_s || 'meta_delivery_failed',
      error_message: error[:title].presence || error[:message].presence,
      failed_at: Time.current
    )
  end
end

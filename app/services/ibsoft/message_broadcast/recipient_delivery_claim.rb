class Ibsoft::MessageBroadcast::RecipientDeliveryClaim
  ELIGIBLE_STATUSES = %w[pending queued].freeze

  def initialize(recipient:)
    @recipient = recipient
  end

  def acquire
    # Conditional SQL update is the compare-and-swap boundary between workers.
    # rubocop:disable Rails/SkipsModelValidations
    claimed = Ibsoft::MessageBroadcast::Recipient
              .where(id: recipient.id, status: ELIGIBLE_STATUSES)
              .update_all(
                status: 'processing',
                processing_started_at: Time.current,
                updated_at: Time.current
              )
    # rubocop:enable Rails/SkipsModelValidations

    recipient.reload if claimed == 1
    claimed == 1
  end

  def fail(error)
    # Only the owner of an active claim may move it to a terminal failure.
    # rubocop:disable Rails/SkipsModelValidations
    Ibsoft::MessageBroadcast::Recipient
      .where(id: recipient.id, status: 'processing')
      .update_all(
        status: 'failed',
        error_code: 'unexpected_delivery_error',
        error_message: error.message,
        processing_started_at: nil,
        updated_at: Time.current
      )
    # rubocop:enable Rails/SkipsModelValidations
  end

  private

  attr_reader :recipient
end

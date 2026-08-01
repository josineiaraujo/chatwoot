class Ibsoft::ExternalMessaging::DeliverySender
  RATE_LIMIT_WAIT = 1.second

  def initialize(delivery:)
    @delivery = delivery
  end

  def call
    return unless claim
    return reschedule if rate_limited?

    increment_attempt!
    @meta_request_started = true
    result = Ibsoft::ExternalMessaging::MetaClient.new(delivery: delivery).send_template
    mark_accepted(result)
  rescue Ibsoft::ExternalMessaging::MetaClient::Error => e
    mark_failed(e)
  rescue StandardError => e
    handle_unexpected_error(e)
  end

  private

  attr_reader :delivery

  def claim
    # Conditional update is the ownership boundary between duplicate workers.
    # rubocop:disable Rails/SkipsModelValidations
    claimed = Ibsoft::ExternalMessaging::Delivery
              .where(id: delivery.id, status: 'queued')
              .update_all(status: 'processing', processing_started_at: Time.current, updated_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
    delivery.reload if claimed == 1
    @claimed = claimed == 1
    claimed == 1
  end

  def rate_limited?
    !Ibsoft::ExternalMessaging::RateLimiter.new(delivery: delivery).acquire
  end

  def reschedule
    # rubocop:disable Rails/SkipsModelValidations
    Ibsoft::ExternalMessaging::Delivery
      .where(id: delivery.id, status: 'processing')
      .update_all(status: 'queued', processing_started_at: nil, enqueued_at: Time.current, updated_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
    Ibsoft::ExternalMessaging::SendDeliveryJob.set(wait: RATE_LIMIT_WAIT).perform_later(delivery.id)
  end

  def increment_attempt!
    delivery.update!(attempts_count: delivery.attempts_count + 1)
  end

  def mark_accepted(result)
    delivery.update!(
      status: 'accepted',
      meta_message_id: result.message_id,
      meta_http_status: result.http_status,
      accepted_at: Time.current,
      processing_started_at: nil,
      error_code: nil,
      error_message: nil,
      template_components: [],
      order_pix_key: nil
    )
  end

  def mark_failed(error)
    delivery.update!(
      status: 'failed',
      meta_http_status: error.http_status,
      error_code: error.code,
      error_message: error.message,
      failed_at: Time.current,
      processing_started_at: nil,
      template_components: [],
      order_pix_key: nil
    )
  end

  def mark_uncertain(error)
    delivery.update!(
      status: 'uncertain',
      error_code: 'delivery_result_uncertain',
      error_message: error.message,
      processing_started_at: nil,
      template_components: [],
      order_pix_key: nil
    )
    Rails.logger.error(
      "[Ibsoft::ExternalMessaging] delivery=#{delivery.id} result=uncertain error=#{error.class}"
    )
  end

  def handle_unexpected_error(error)
    raise error unless @claimed

    return mark_uncertain(error) if @meta_request_started

    defer_after_infrastructure_error(error)
  end

  def defer_after_infrastructure_error(error)
    # No request reached Meta, so this record remains safe to recover.
    # rubocop:disable Rails/SkipsModelValidations
    Ibsoft::ExternalMessaging::Delivery
      .where(id: delivery.id, status: %w[queued processing])
      .update_all(
        status: 'queued',
        processing_started_at: nil,
        enqueued_at: nil,
        updated_at: Time.current
      )
    # rubocop:enable Rails/SkipsModelValidations
    Rails.logger.error(
      "[Ibsoft::ExternalMessaging] delivery=#{delivery.id} deferred error=#{error.class}"
    )
  end
end

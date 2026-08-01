class Ibsoft::ExternalMessaging::OrderUpdateSender
  RATE_LIMIT_WAIT = 1.second

  def initialize(update:)
    @update = update
  end

  def call
    return unless claim
    return reschedule if rate_limited?
    return unless valid_against_current_state?

    increment_attempt!
    @meta_request_started = true
    result = Ibsoft::ExternalMessaging::MetaClient.new(order_update: update).send_order_status
    mark_accepted(result)
  rescue Ibsoft::ExternalMessaging::MetaClient::Error => e
    mark_failed(e)
  rescue StandardError => e
    handle_unexpected_error(e)
  ensure
    enqueue_next unless update.reload.status.in?(%w[queued processing uncertain])
  end

  private

  attr_reader :update

  def claim
    @claimed = update.order.with_lock do
      update.reload
      next false unless update.status == 'queued'
      next false if earlier_blocking_update?

      update.update!(status: 'processing', processing_started_at: Time.current)
    end
  end

  def earlier_blocking_update?
    update.order.updates
          .where('id < ?', update.id)
          .exists?(status: %w[queued processing uncertain])
  end

  def rate_limited?
    !Ibsoft::ExternalMessaging::RateLimiter.new(record: update).acquire
  end

  def reschedule
    update.update!(
      status: 'queued',
      processing_started_at: nil,
      enqueued_at: Time.current
    )
    Ibsoft::ExternalMessaging::SendOrderUpdateJob.set(wait: RATE_LIMIT_WAIT).perform_later(update.id)
  end

  def valid_against_current_state?
    update.order.with_lock do
      update.order.reload
      if requested_statuses_match_current?
        mark_unchanged
      elsif cancellation_conflict?
        mark_cancellation_conflict
      else
        true
      end
    end
  end

  def requested_statuses_match_current?
    (update.order_status.blank? || update.order_status == update.order.order_status) &&
      (update.payment_status.blank? || update.payment_status == update.order.payment_status)
  end

  def cancellation_conflict?
    update.order_status == 'canceled' && update.order.payment_status.in?(%w[pending captured])
  end

  def mark_unchanged
    update.update!(
      status: 'unchanged',
      processing_started_at: nil,
      error_code: nil,
      error_message: nil
    )
    false
  end

  def mark_cancellation_conflict
    update.update!(
      status: 'failed',
      error_code: 'order_update_cancellation_conflict',
      error_message: I18n.t('ibsoft_external_messaging.errors.order_update_cancellation_conflict'),
      failed_at: Time.current,
      processing_started_at: nil
    )
    false
  end

  def increment_attempt!
    update.update!(attempts_count: update.attempts_count + 1)
  end

  def mark_accepted(result)
    update.order.with_lock do
      update.order.update!(
        order_status: update.order_status || update.order.order_status,
        payment_status: update.payment_status || update.order.payment_status
      )
      update.update!(
        status: 'accepted',
        meta_message_id: result.message_id,
        meta_http_status: result.http_status,
        accepted_at: Time.current,
        processing_started_at: nil,
        error_code: nil,
        error_message: nil
      )
    end
  end

  def mark_failed(error)
    return unless @claimed

    update.update!(
      status: 'failed',
      meta_http_status: error.http_status,
      error_code: error.code,
      error_message: error.message,
      failed_at: Time.current,
      processing_started_at: nil
    )
  end

  def mark_uncertain(error)
    update.reload
    update.update!(
      status: 'uncertain',
      error_code: 'delivery_result_uncertain',
      error_message: error.message,
      processing_started_at: nil
    )
    Rails.logger.error(
      "[Ibsoft::ExternalMessaging] order_update=#{update.id} result=uncertain error=#{error.class}"
    )
  end

  def handle_unexpected_error(error)
    raise error unless @claimed

    return mark_uncertain(error) if @meta_request_started

    defer_after_infrastructure_error(error)
  end

  def defer_after_infrastructure_error(error)
    update.update!(
      status: 'queued',
      processing_started_at: nil,
      enqueued_at: nil
    )
    Rails.logger.error(
      "[Ibsoft::ExternalMessaging] order_update=#{update.id} deferred error=#{error.class}"
    )
  end

  def enqueue_next
    next_update = update.order.updates.where(status: 'queued').order(:id).first
    return if next_update.blank?
    return if update.order.updates.exists?(status: %w[processing uncertain])

    Ibsoft::ExternalMessaging::SendOrderUpdateJob.perform_later(next_update.id)
    next_update.update_column(:enqueued_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
  rescue StandardError => e
    Rails.logger.error(
      "[Ibsoft::ExternalMessaging] next enqueue failed order_update=#{next_update&.id} error=#{e.class}"
    )
  end
end

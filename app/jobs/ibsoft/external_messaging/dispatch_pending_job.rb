class Ibsoft::ExternalMessaging::DispatchPendingJob < ApplicationJob
  queue_as :scheduled_jobs

  BATCH_SIZE = 500
  REENQUEUE_AFTER = 5.minutes
  UNCERTAIN_AFTER = 15.minutes

  def perform
    mark_stale_processing_uncertain
    mark_stale_order_updates_uncertain
    enqueue_pending
    enqueue_pending_order_updates
  end

  private

  def enqueue_pending
    pending_scope.limit(BATCH_SIZE).pluck(:id).each do |delivery_id|
      Ibsoft::ExternalMessaging::SendDeliveryJob.perform_later(delivery_id)
      mark_enqueued(delivery_id)
    rescue StandardError => e
      Rails.logger.error(
        "[Ibsoft::ExternalMessaging] enqueue failed delivery=#{delivery_id} error=#{e.class}"
      )
    end
  end

  def pending_scope
    Ibsoft::ExternalMessaging::Delivery
      .where(status: 'queued')
      .where('enqueued_at IS NULL OR enqueued_at < ?', REENQUEUE_AFTER.ago)
      .order(:created_at, :id)
  end

  def mark_enqueued(delivery_id)
    # rubocop:disable Rails/SkipsModelValidations
    Ibsoft::ExternalMessaging::Delivery
      .where(id: delivery_id, status: 'queued')
      .update_all(enqueued_at: Time.current, updated_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def mark_stale_processing_uncertain
    # A worker may have received a Meta response before it crashed. Never resend
    # these automatically because the Meta messages endpoint has no idempotency key.
    # rubocop:disable Rails/SkipsModelValidations
    Ibsoft::ExternalMessaging::Delivery
      .where(status: 'processing')
      .where('processing_started_at < ?', UNCERTAIN_AFTER.ago)
      .update_all(
        status: 'uncertain',
        error_code: 'worker_interrupted',
        error_message: I18n.t('ibsoft_external_messaging.errors.worker_interrupted'),
        processing_started_at: nil,
        updated_at: Time.current
      )
    # rubocop:enable Rails/SkipsModelValidations
  end

  def enqueue_pending_order_updates
    pending_order_updates.limit(BATCH_SIZE).pluck(:id).each do |update_id|
      Ibsoft::ExternalMessaging::SendOrderUpdateJob.perform_later(update_id)
      mark_order_update_enqueued(update_id)
    rescue StandardError => e
      Rails.logger.error(
        "[Ibsoft::ExternalMessaging] enqueue failed order_update=#{update_id} error=#{e.class}"
      )
    end
  end

  def pending_order_updates
    scope = Ibsoft::ExternalMessaging::OrderUpdate
            .where(status: 'queued')
            .where('enqueued_at IS NULL OR enqueued_at < ?', REENQUEUE_AFTER.ago)
            .where.not(
              order_id: Ibsoft::ExternalMessaging::OrderUpdate
                        .where(status: %w[processing uncertain])
                        .select(:order_id)
            )
    scope.where(
      id: Ibsoft::ExternalMessaging::OrderUpdate
          .where(status: 'queued')
          .group(:order_id)
          .select('MIN(id)')
    ).order(:created_at, :id)
  end

  def mark_order_update_enqueued(update_id)
    # rubocop:disable Rails/SkipsModelValidations
    Ibsoft::ExternalMessaging::OrderUpdate
      .where(id: update_id, status: 'queued')
      .update_all(enqueued_at: Time.current, updated_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def mark_stale_order_updates_uncertain
    # A response may have reached the interrupted worker. Keep later updates
    # blocked until an operator reconciles this order.
    # rubocop:disable Rails/SkipsModelValidations
    Ibsoft::ExternalMessaging::OrderUpdate
      .where(status: 'processing')
      .where('processing_started_at < ?', UNCERTAIN_AFTER.ago)
      .update_all(
        status: 'uncertain',
        error_code: 'worker_interrupted',
        error_message: I18n.t('ibsoft_external_messaging.errors.worker_interrupted'),
        processing_started_at: nil,
        updated_at: Time.current
      )
    # rubocop:enable Rails/SkipsModelValidations
  end
end

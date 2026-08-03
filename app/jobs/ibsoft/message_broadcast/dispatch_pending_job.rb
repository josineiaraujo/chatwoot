class Ibsoft::MessageBroadcast::DispatchPendingJob < ApplicationJob
  queue_as :scheduled_jobs

  BATCH_SIZE = 500
  REENQUEUE_AFTER = 5.minutes
  UNCERTAIN_AFTER = 15.minutes

  def perform
    mark_stale_processing_uncertain
    enqueue_broadcasts
    enqueue_recipients
    finalize_inactive_broadcasts
  end

  private

  def enqueue_broadcasts
    Ibsoft::MessageBroadcast::Broadcast
      .where(status: 'queued')
      .where('updated_at < ?', REENQUEUE_AFTER.ago)
      .order(:created_at, :id)
      .limit(BATCH_SIZE)
      .pluck(:id)
      .each { |broadcast_id| enqueue_broadcast(broadcast_id) }
  end

  def enqueue_broadcast(broadcast_id)
    Ibsoft::MessageBroadcast::SendBroadcastJob.perform_later(broadcast_id)
    # rubocop:disable Rails/SkipsModelValidations
    Ibsoft::MessageBroadcast::Broadcast
      .where(id: broadcast_id, status: 'queued')
      .update_all(updated_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
  rescue StandardError => e
    Rails.logger.error(
      "[Ibsoft::MessageBroadcast] enqueue failed broadcast=#{broadcast_id} error=#{e.class}"
    )
  end

  def enqueue_recipients
    pending_recipient_scope.limit(BATCH_SIZE).pluck(:id).each do |recipient_id|
      Ibsoft::MessageBroadcast::SendRecipientJob.perform_later(recipient_id)
      mark_recipient_enqueued(recipient_id)
    rescue StandardError => e
      Rails.logger.error(
        "[Ibsoft::MessageBroadcast] enqueue failed recipient=#{recipient_id} error=#{e.class}"
      )
    end
  end

  def pending_recipient_scope
    Ibsoft::MessageBroadcast::Recipient
      .joins(:broadcast)
      .where(status: 'queued', ibsoft_message_broadcasts: { status: 'running', dispatch_mode: 'bulk' })
      .where('enqueued_at IS NULL OR enqueued_at < ?', REENQUEUE_AFTER.ago)
      .order('ibsoft_message_broadcast_recipients.created_at ASC', 'ibsoft_message_broadcast_recipients.id ASC')
  end

  def mark_recipient_enqueued(recipient_id)
    # rubocop:disable Rails/SkipsModelValidations
    Ibsoft::MessageBroadcast::Recipient
      .where(id: recipient_id, status: 'queued')
      .update_all(enqueued_at: Time.current, updated_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def mark_stale_processing_uncertain
    # Meta does not offer an idempotency key for this endpoint. A worker may
    # have sent successfully before being interrupted, so never resend it.
    # rubocop:disable Rails/SkipsModelValidations
    Ibsoft::MessageBroadcast::Recipient
      .where(status: 'processing')
      .where('processing_started_at < ?', UNCERTAIN_AFTER.ago)
      .update_all(
        status: 'uncertain',
        error_code: 'worker_interrupted',
        error_message: I18n.t('ibsoft.message_broadcast.errors.worker_interrupted'),
        processing_started_at: nil,
        updated_at: Time.current
      )
    # rubocop:enable Rails/SkipsModelValidations
  end

  def finalize_inactive_broadcasts
    Ibsoft::MessageBroadcast::Broadcast.where(status: 'running').find_each do |broadcast|
      Ibsoft::MessageBroadcast::BroadcastFinalizer.new(broadcast: broadcast).call
    end
  end
end

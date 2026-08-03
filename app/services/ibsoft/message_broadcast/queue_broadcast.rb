class Ibsoft::MessageBroadcast::QueueBroadcast
  RESULT_QUEUED = :queued
  RESULT_INVALID_STATUS = :invalid_status
  RESULT_WITHOUT_RECIPIENTS = :without_pending_recipients

  def initialize(broadcast:, sent_by:)
    @broadcast = broadcast
    @sent_by = sent_by
  end

  def call
    result = RESULT_INVALID_STATUS

    Ibsoft::MessageBroadcast::Broadcast.transaction do
      now = Time.current
      claimed = claim_broadcast(now)
      next if claimed.zero?

      if queue_recipients(now).zero?
        result = RESULT_WITHOUT_RECIPIENTS
        raise ActiveRecord::Rollback
      end

      result = RESULT_QUEUED
    end

    broadcast.reload if result == RESULT_QUEUED
    result
  end

  private

  attr_reader :broadcast, :sent_by

  def claim_broadcast(now)
    # Conditional SQL update lets only one request queue the draft.
    # rubocop:disable Rails/SkipsModelValidations
    Ibsoft::MessageBroadcast::Broadcast
      .where(id: broadcast.id, status: 'draft')
      .update_all(
        status: 'queued',
        sent_by_id: sent_by.id,
        started_at: nil,
        finished_at: nil,
        updated_at: now
      )
    # rubocop:enable Rails/SkipsModelValidations
  end

  def queue_recipients(now)
    # Bulk transition is part of the same database transaction as the claim.
    # rubocop:disable Rails/SkipsModelValidations
    Ibsoft::MessageBroadcast::Recipient
      .where(broadcast_id: broadcast.id, status: 'pending')
      .update_all(
        status: 'queued',
        enqueued_at: nil,
        processing_started_at: nil,
        updated_at: now
      )
    # rubocop:enable Rails/SkipsModelValidations
  end
end

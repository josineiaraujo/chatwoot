class Ibsoft::MessageBroadcast::RecipientSender
  RESULT_DELIVERED = :delivered
  RESULT_FAILED = :failed
  RESULT_SKIPPED = :skipped
  RESULT_UNCERTAIN = :uncertain
  RESULT_RATE_LIMITED = :rate_limited

  def initialize(broadcast:, recipient:)
    @broadcast = broadcast
    @recipient = recipient
  end

  def call
    @delivery_claim = Ibsoft::MessageBroadcast::RecipientDeliveryClaim.new(recipient: recipient)
    return false unless delivery_claim.acquire
    return skip_without_phone! if phone_candidates.blank?
    return release_rate_limited! if rate_limited?

    deliver_to_candidates
  rescue StandardError => e
    delivery_claim&.fail(e)
    raise
  end

  private

  attr_reader :broadcast, :recipient, :delivery_claim

  def phone_candidates
    @phone_candidates ||= Ibsoft::MessageBroadcast::RecipientPhoneCandidates.new(
      primary_phone: recipient.primary_phone,
      fallback_phone: recipient.fallback_phone
    ).call
  end

  def deliver_to_candidates
    last_error = nil

    phone_candidates.each_with_index do |phone_candidate, index|
      result = delivery_strategy.call(phone_candidate)
      return mark_accepted!(phone_candidate, result)
    rescue Ibsoft::MessageBroadcast::MetaTemplateClient::UncertainError => e
      return mark_uncertain!(phone_candidate, e)
    rescue Ibsoft::MessageBroadcast::MetaTemplateClient::Error => e
      last_error = e
      next if fallback_available?(index, e)

      return mark_failed!(phone_candidate, e)
    end

    mark_failed!(phone_candidates.last, last_error)
  end

  def fallback_available?(index, error)
    error.fallback_eligible? && phone_candidates[index + 1].present?
  end

  def delivery_strategy
    @delivery_strategy ||= if broadcast.direct_delivery?
                             Ibsoft::MessageBroadcast::DirectRecipientDelivery.new(
                               broadcast: broadcast,
                               recipient: recipient
                             )
                           else
                             Ibsoft::MessageBroadcast::ConversationRecipientDelivery.new(
                               broadcast: broadcast,
                               recipient: recipient
                             )
                           end
  end

  def rate_limited?
    return false if broadcast.single_dispatch?

    !Ibsoft::MessageBroadcast::RateLimiter.new(broadcast: broadcast).acquire
  end

  def release_rate_limited!
    now = Time.current
    # rubocop:disable Rails/SkipsModelValidations
    Ibsoft::MessageBroadcast::Recipient
      .where(id: recipient.id, status: 'processing')
      .update_all(
        status: 'queued',
        processing_started_at: nil,
        enqueued_at: now,
        updated_at: now
      )
    # rubocop:enable Rails/SkipsModelValidations
    RESULT_RATE_LIMITED
  end

  def mark_accepted!(phone_candidate, result)
    recipient.update!(
      status: 'accepted',
      phone_status: phone_candidate.kind,
      phone_used: phone_candidate.phone_number,
      meta_message_id: result.meta_message_id,
      conversation: result.conversation,
      message: result.message,
      processing_started_at: nil,
      error_code: nil,
      error_message: nil
    )
    RESULT_DELIVERED
  end

  def skip_without_phone!
    recipient.update!(
      status: 'skipped',
      phone_status: 'unavailable',
      processing_started_at: nil,
      error_code: 'without_valid_phone',
      error_message: nil
    )
    RESULT_SKIPPED
  end

  def mark_failed!(phone_candidate, error)
    recipient.update!(
      status: 'failed',
      phone_status: phone_candidate&.kind || 'invalid',
      phone_used: phone_candidate&.phone_number,
      processing_started_at: nil,
      error_code: error&.code || 'delivery_failed',
      error_message: error&.message
    )
    RESULT_FAILED
  end

  def mark_uncertain!(phone_candidate, error)
    recipient.update!(
      status: 'uncertain',
      phone_status: phone_candidate.kind,
      phone_used: phone_candidate.phone_number,
      processing_started_at: nil,
      error_code: error.code,
      error_message: error.message
    )
    RESULT_UNCERTAIN
  end
end

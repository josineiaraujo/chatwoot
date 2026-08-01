class Ibsoft::ExternalMessaging::CleanupEndpointRecordsJob < ApplicationJob
  queue_as :purgable

  LOCK_TTL = 1.hour.to_i

  def perform(endpoint_id)
    endpoint = Ibsoft::ExternalMessaging::Endpoint.find_by(id: endpoint_id)
    return if endpoint.blank?

    @lock_key = "ibsoft:external_messaging:retention_cleanup:endpoint:#{endpoint.id}"
    @lock_token = SecureRandom.uuid
    return unless acquire_lock

    result = Ibsoft::ExternalMessaging::RetentionCleanup.new(endpoint: endpoint).call
    log_result(endpoint, result)
  ensure
    release_lock
  end

  private

  attr_reader :lock_key, :lock_token

  def acquire_lock
    Redis::Alfred.set(lock_key, lock_token, nx: true, ex: LOCK_TTL).present?
  end

  def release_lock
    return if lock_key.blank? || lock_token.blank?

    Redis::Alfred.delete_if_equals(lock_key, lock_token)
  end

  def log_result(endpoint, result)
    return if result.orders.zero? && result.order_updates.zero? && result.deliveries.zero?

    Rails.logger.info(
      "[Ibsoft::ExternalMessaging] retention endpoint=#{endpoint.id} " \
      "orders=#{result.orders} updates=#{result.order_updates} deliveries=#{result.deliveries}"
    )
  end
end

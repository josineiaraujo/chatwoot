class Ibsoft::ExternalMessaging::CleanupExpiredRecordsJob < ApplicationJob
  queue_as :scheduled_jobs

  LOCK_KEY = 'ibsoft:external_messaging:retention_cleanup:v1'.freeze
  LOCK_TTL = 10.minutes.to_i

  def perform
    @lock_token = SecureRandom.uuid
    return unless acquire_lock

    Ibsoft::ExternalMessaging::Endpoint.find_each do |endpoint|
      Ibsoft::ExternalMessaging::CleanupEndpointRecordsJob.perform_later(endpoint.id)
    end
  ensure
    release_lock
  end

  private

  attr_reader :lock_token

  def acquire_lock
    Redis::Alfred.set(LOCK_KEY, lock_token, nx: true, ex: LOCK_TTL).present?
  end

  def release_lock
    return if lock_token.blank?

    Redis::Alfred.delete_if_equals(LOCK_KEY, lock_token)
  end
end

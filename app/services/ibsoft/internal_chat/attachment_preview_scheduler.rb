class Ibsoft::InternalChat::AttachmentPreviewScheduler
  SCHEDULE_LOCK_TTL = 5.minutes

  def initialize(streamable:)
    @streamable = streamable
    @lock_token = SecureRandom.uuid
  end

  def perform
    return unless schedulable?
    return unless acquire_schedule_lock

    enqueue_preview
  rescue StandardError
    release_schedule_lock
    raise
  end

  private

  attr_reader :lock_token, :streamable

  def schedulable?
    streamable.is_a?(ActiveStorage::Preview) ||
      streamable.is_a?(ActiveStorage::Variant) ||
      streamable.is_a?(ActiveStorage::VariantWithRecord)
  end

  def acquire_schedule_lock
    @lock_acquired = Redis::Alfred.set(
      cache_key,
      lock_token,
      nx: true,
      ex: SCHEDULE_LOCK_TTL.to_i
    ).present?
  end

  def release_schedule_lock
    return unless @lock_acquired

    Redis::Alfred.delete_if_equals(cache_key, lock_token)
  rescue Redis::BaseError
    nil
  end

  def cache_key
    return @cache_key if defined?(@cache_key)
    return unless schedulable?

    @cache_key = "ibsoft:internal-chat:preview:#{streamable.blob.key}:#{streamable.variation.key}"
  end

  def enqueue_preview
    if streamable.is_a?(ActiveStorage::Preview)
      streamable.blob.create_preview_image_later([streamable.variation.transformations])
    else
      streamable.blob.preprocessed(streamable.variation.transformations)
    end
  end
end

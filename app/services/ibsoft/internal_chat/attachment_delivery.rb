class Ibsoft::InternalChat::AttachmentDelivery
  SIGNED_URL_TTL = 1.minute

  Result = Struct.new(:status, :streamable, :url, keyword_init: true) do
    def stream? = status == :stream
    def redirect? = status == :redirect
    def pending? = status == :pending
  end

  def initialize(streamable:)
    @streamable = streamable
  end

  def perform
    return result(:missing) if streamable.blank?
    return result(:pending) unless processed?
    return result(:stream, streamable: streamable) if disk_service?

    signed_url = streamable.url(expires_in: SIGNED_URL_TTL, disposition: :inline)
    signed_url.present? ? result(:redirect, url: signed_url) : result(:missing)
  rescue ActiveStorage::Preview::UnprocessedError
    result(:pending)
  rescue ActiveStorage::FileNotFoundError
    result(:missing)
  end

  private

  attr_reader :streamable

  def result(status, streamable: nil, url: nil)
    Result.new(status: status, streamable: streamable, url: url)
  end

  def disk_service?
    storage_service.is_a?(ActiveStorage::Service::DiskService)
  end

  def storage_service
    return streamable.service if streamable.respond_to?(:service)
    return streamable.blob.service if streamable.respond_to?(:blob)

    ActiveStorage::Blob.service
  end

  def processed?
    return preview_processed? if streamable.is_a?(ActiveStorage::Preview)
    return streamable.image.present? if streamable.is_a?(ActiveStorage::VariantWithRecord)
    return storage_service.exist?(streamable.key) if streamable.is_a?(ActiveStorage::Variant)

    true
  end

  def preview_processed?
    return false unless streamable.image.attached?

    preview_variant = streamable.image.variant(streamable.variation)
    return preview_variant.image.present? if preview_variant.is_a?(ActiveStorage::VariantWithRecord)

    preview_variant.service.exist?(preview_variant.key)
  end
end

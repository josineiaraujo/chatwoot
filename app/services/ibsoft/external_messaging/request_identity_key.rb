require 'digest'

class Ibsoft::ExternalMessaging::RequestIdentityKey
  def initialize(fields:)
    @fields = fields.to_h.stringify_keys
  end

  def call
    return "request-#{SecureRandom.uuid}" if order_reference_id.blank?

    fingerprint = Digest::SHA256.hexdigest(
      [fields['template_name'], order_reference_id].join("\0")
    )
    "order-#{fingerprint}"
  end

  private

  attr_reader :fields

  def order_reference_id
    fields['order.reference_id'].to_s.strip.presence
  end
end

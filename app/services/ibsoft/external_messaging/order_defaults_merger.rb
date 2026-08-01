class Ibsoft::ExternalMessaging::OrderDefaultsMerger
  FIELD_MAPPING = {
    'order.payment.pix.merchant_name' => :order_pix_merchant_name,
    'order.payment.pix.key' => :order_pix_key,
    'order.payment.pix.key_type' => :order_pix_key_type
  }.freeze

  def initialize(endpoint:, fields:)
    @endpoint = endpoint
    @fields = fields.to_h.deep_stringify_keys
  end

  def call
    return fields unless order_with_pix?

    FIELD_MAPPING.each_with_object(fields.dup) do |(field, attribute), merged|
      merged[field] = endpoint.public_send(attribute) if merged[field].blank? && endpoint.public_send(attribute).present?
    end
  end

  private

  attr_reader :endpoint, :fields

  def order_with_pix?
    fields['template_type'].to_s.strip.casecmp('order').zero? &&
      fields['order.payment.pix.code'].present?
  end
end

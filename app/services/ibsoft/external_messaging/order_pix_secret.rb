class Ibsoft::ExternalMessaging::OrderPixSecret
  KEY_REFERENCE = '__ibsoft_external_order_pix_key__'.freeze
  Result = Data.define(:components, :key)

  class MissingKey < StandardError; end

  def self.extract(components)
    normalized = deep_copy(components)
    pix = pix_configuration(normalized)
    return Result.new(components: normalized, key: nil) if pix.blank?

    key = pix['key'].to_s
    pix['key'] = KEY_REFERENCE
    Result.new(components: normalized, key: key)
  end

  def self.materialize(components:, key:)
    normalized = deep_copy(components)
    pix = pix_configuration(normalized)
    return normalized unless pix&.fetch('key', nil) == KEY_REFERENCE
    raise MissingKey if key.blank?

    pix['key'] = key
    normalized
  end

  def self.pix_configuration(components)
    Array(components).filter_map do |component|
      component
        .dig('parameters', 0, 'action', 'order_details', 'payment_settings')
        &.find { |setting| setting['type'] == 'pix_dynamic_code' }
        &.fetch('pix_dynamic_code', nil)
    end.first
  end
  private_class_method :pix_configuration

  def self.deep_copy(value)
    JSON.parse(JSON.generate(value))
  end
  private_class_method :deep_copy
end

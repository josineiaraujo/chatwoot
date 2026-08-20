class Ibsoft::ExternalMessaging::OrderUpdateTemplateSettings
  class ValidationError < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super(I18n.t("ibsoft_external_messaging.errors.#{code}"))
    end
  end

  def initialize(endpoint:, attributes:, template_catalog: nil)
    @endpoint = endpoint
    @attributes = attributes.to_h.with_indifferent_access
    @template_catalog = template_catalog || Ibsoft::ExternalMessaging::OrderUpdateTemplateCatalog.new(endpoint: endpoint)
  end

  def assign
    mode = attributes.fetch(:mode, endpoint.order_update_delivery_mode).to_s
    raise_error('order_update_delivery_mode_invalid') unless mode.in?(endpoint.class::ORDER_UPDATE_DELIVERY_MODES)

    endpoint.order_update_delivery_mode = mode
    return endpoint.order_update_template_settings = {} if mode == 'interactive'

    endpoint.order_update_template_settings = build_template_settings
  end

  private

  attr_reader :endpoint, :attributes, :template_catalog

  def build_template_settings
    default_template = template_descriptor(attributes[:default_template_id])
    raise_error('order_update_default_template_required') if default_template.blank?

    {
      'default' => default_template,
      'overrides' => normalized_overrides
    }
  end

  def normalized_overrides
    raw_overrides = attributes.fetch(:overrides, {})
    raise_error('order_update_template_override_invalid') unless raw_overrides.respond_to?(:to_h)

    overrides = raw_overrides.to_h.with_indifferent_access
    unknown_keys = overrides.keys.map(&:to_s) - endpoint.class::ORDER_UPDATE_MESSAGE_KEYS
    raise_error('order_update_template_override_invalid') if unknown_keys.any?

    overrides.each_with_object({}) do |(key, template_id), result|
      next if template_id.blank?

      result[key.to_s] = template_descriptor(template_id)
    end
  end

  def template_descriptor(template_id)
    return if template_id.blank?

    template_catalog.find(template_id) || raise_error('order_update_template_invalid')
  end

  def raise_error(code)
    raise ValidationError, code
  end
end

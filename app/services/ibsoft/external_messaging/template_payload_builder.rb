class Ibsoft::ExternalMessaging::TemplatePayloadBuilder
  TEMPLATE_NAME_PATTERN = /\A[a-z0-9_]{1,512}\z/
  LANGUAGE_PATTERN = /\A[a-z]{2,3}(?:_[A-Z]{2})?\z/
  METADATA_FIELDS = %w[template_name template_type template_language tipo-canal id-canal].freeze

  def initialize(fields:)
    @fields = fields.to_h.deep_stringify_keys
  end

  def call
    validate_metadata!
    components = build_components

    {
      template_name: template_name,
      template_language: template_language,
      template_type: order_template? ? 'order' : 'standard',
      template_components: JSON.parse(JSON.generate(components)),
      order_reference_id: order_reference(components)
    }
  end

  private

  attr_reader :fields

  def validate_metadata!
    validate_template_identity!
    validate_channel_type!
    validate_supported_fields!
    validate_order_fields!
  end

  def validate_template_identity!
    raise_error('template_name_invalid') unless template_name.match?(TEMPLATE_NAME_PATTERN)
    raise_error('template_language_invalid') unless template_language.match?(LANGUAGE_PATTERN)
    raise_error('template_type_invalid') unless template_type.in?(%w[simple order])
  end

  def validate_channel_type!
    channel_type = fields['tipo-canal'].to_s.strip.downcase
    raise_error('channel_type_invalid') if channel_type.present? && channel_type != 'whatsapp-cloud'
  end

  def validate_supported_fields!
    invalid = fields.keys.find do |field|
      !field.in?(METADATA_FIELDS) &&
        !field.start_with?('header.', 'body.', 'button.', 'order.') &&
        !field.in?(Ibsoft::ExternalMessaging::HeaderComponentBuilder::ALIASES.values)
    end
    raise_error('unsupported_field', field: invalid) if invalid
  end

  def validate_order_fields!
    has_order_fields = fields.keys.any? { |field| field.start_with?('order.') }
    return if order_template? || !has_order_fields

    raise_error('order_fields_require_order')
  end

  def build_components
    components = []
    components << Ibsoft::ExternalMessaging::HeaderComponentBuilder.new(fields: fields).call
    components << Ibsoft::ExternalMessaging::BodyComponentBuilder.new(fields: fields).call
    buttons = Ibsoft::ExternalMessaging::ButtonComponentsBuilder.new(fields: fields).call

    if order_template?
      order_button = Ibsoft::ExternalMessaging::OrderComponentBuilder.new(fields: fields).call
      raise_error('order_button_conflict') if buttons.key?(order_button[:index])

      buttons[order_button[:index]] = order_button
    end

    components.concat(buttons.sort.to_h.values)
    components.compact
  end

  def order_reference(components)
    order = components.filter_map do |component|
      component.dig(:parameters, 0, :action, :order_details) if component[:sub_type] == 'order_details'
    end.first
    order&.fetch(:reference_id, nil)
  end

  def template_name
    @template_name ||= fields['template_name'].to_s.strip.downcase
  end

  def template_language
    @template_language ||= fields.fetch('template_language', 'pt_BR').to_s.strip
  end

  def template_type
    @template_type ||= fields.fetch('template_type', 'simple').to_s.strip.downcase
  end

  def order_template?
    template_type == 'order'
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end

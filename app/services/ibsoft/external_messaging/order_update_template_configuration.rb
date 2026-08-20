class Ibsoft::ExternalMessaging::OrderUpdateTemplateConfiguration
  DELIVERY_MODES = %w[interactive template].freeze
  DESCRIPTOR_KEYS = %w[id name language parameter_format body_parameter].freeze
  NAMED_PARAMETER_PATTERN = /\A[a-z][a-z0-9_]*\z/

  def initialize(mode:, settings:)
    @mode = mode.to_s
    @settings = normalize_settings(settings)
  end

  def normalized_settings
    mode == 'interactive' ? {} : settings
  end

  def valid?
    return true if mode == 'interactive'
    return false unless mode == 'template'

    template_settings_valid?
  end

  def ready?
    mode == 'template' && descriptor_valid?(settings['default'])
  end

  private

  attr_reader :mode, :settings

  def normalize_settings(source)
    return {} unless source.is_a?(Hash)

    source.to_h.deep_stringify_keys
  end

  def template_settings_valid?
    return false unless (settings.keys - %w[default overrides]).empty?
    return false unless descriptor_valid?(settings['default'])

    overrides_valid?
  end

  def overrides_valid?
    overrides = settings['overrides']
    return false unless overrides.is_a?(Hash)
    return false if (overrides.keys - Ibsoft::ExternalMessaging::OrderUpdateMessageCatalog::KEYS).any?

    overrides.values.all? { |descriptor| descriptor_valid?(descriptor) }
  end

  def descriptor_valid?(descriptor)
    return false unless descriptor.is_a?(Hash)

    normalized = descriptor.to_h.deep_stringify_keys
    return false if (normalized.keys - DESCRIPTOR_KEYS).any?
    return false unless normalized.values_at('id', 'name', 'language').all?(&:present?)

    parameter_format = normalized['parameter_format']
    return false unless parameter_format.in?(%w[NAMED POSITIONAL])

    body_parameter_valid?(normalized['body_parameter'], parameter_format)
  end

  def body_parameter_valid?(parameter, parameter_format)
    return true if parameter.nil?
    return false unless parameter.is_a?(Hash)

    normalized = parameter.to_h.deep_stringify_keys
    return false unless normalized.keys.sort == %w[format key]

    parameter_format == 'NAMED' ? named_parameter_valid?(normalized) : positional_parameter_valid?(normalized)
  end

  def named_parameter_valid?(parameter)
    parameter['format'] == 'named' && parameter['key'].match?(NAMED_PARAMETER_PATTERN)
  end

  def positional_parameter_valid?(parameter)
    parameter == { 'format' => 'positional', 'key' => '1' }
  end
end

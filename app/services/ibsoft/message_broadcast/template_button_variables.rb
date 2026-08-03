class Ibsoft::MessageBroadcast::TemplateButtonVariables
  VARIABLE_PATTERN = /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/
  RUNTIME_TYPES = %w[URL COPY_CODE].freeze

  def initialize(buttons)
    @buttons = buttons
  end

  def call
    Array(buttons).each_with_index.filter_map do |button, index|
      normalized_button = button.with_indifferent_access
      button_type = normalized_button[:type].to_s.upcase
      next unless RUNTIME_TYPES.include?(button_type)

      parameter_key = parameter_key(normalized_button, button_type)
      next if parameter_key.blank?

      variable(normalized_button, button_type, parameter_key, index)
    end
  end

  private

  attr_reader :buttons

  def parameter_key(button, button_type)
    return 'copy_code' if button_type == 'COPY_CODE'

    button[:url].to_s.scan(VARIABLE_PATTERN).flatten.first
  end

  def variable(button, button_type, parameter_key, index)
    {
      key: "buttons:#{index}:#{parameter_key}",
      parameter_key: parameter_key,
      label: "{{#{parameter_key}}}",
      component_type: 'BUTTONS',
      parameter_type: 'text',
      button_type: button_type.downcase,
      button_index: index,
      button_text: button[:text]
    }.compact
  end
end

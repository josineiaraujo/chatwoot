class Ibsoft::ExternalMessaging::TemplateContentRenderer
  PLACEHOLDER_PATTERN = /\{\{([^}]+)\}\}/

  def initialize(endpoint:, attributes:)
    @endpoint = endpoint
    @attributes = attributes
  end

  def call
    body = template_definition&.fetch('components', [])&.find { |component| component['type'].to_s.casecmp('BODY').zero? }
    text = body&.fetch('text', nil).to_s
    return fallback_content if text.blank?

    replace_placeholders(text)
  end

  private

  attr_reader :endpoint, :attributes

  def fallback_content
    attributes[:message_content].presence ||
      "[#{attributes[:template_name]}:#{attributes[:template_language]}]"
  end

  def template_definition
    @template_definition ||= Array(endpoint.inbox.channel.message_templates).find do |template|
      template['name'] == attributes[:template_name] &&
        template['language'] == attributes[:template_language]
    end
  end

  def replace_placeholders(text)
    parameters = body_parameters
    named = parameters.index_by { |parameter| parameter['parameter_name'].to_s }
    positional_index = 0

    text.gsub(PLACEHOLDER_PATTERN) do
      key = ::Regexp.last_match(1).to_s.strip
      parameter = named[key]
      parameter ||= parameters[positional_index].tap { positional_index += 1 } if key.match?(/\A\d+\z/)
      parameter_value(parameter) || ::Regexp.last_match(0)
    end
  end

  def body_parameters
    body = Array(attributes[:template_components]).find { |component| component['type'].to_s.casecmp('body').zero? }
    Array(body&.fetch('parameters', []))
  end

  def parameter_value(parameter)
    return if parameter.blank?

    parameter['text'].presence ||
      parameter.dig('currency', 'fallback_value').presence ||
      parameter.dig('date_time', 'fallback_value').presence
  end
end

class Ibsoft::ExternalMessaging::OrderUpdateTemplateCatalog
  VARIABLE_PATTERN = /\{\{\s*([^{}]+?)\s*\}\}/
  SUPPORTED_STATUS = 'APPROVED'.freeze
  SUPPORTED_CATEGORY = 'UTILITY'.freeze
  SUPPORTED_SUB_CATEGORY = 'ORDER_STATUS'.freeze
  MEDIA_HEADER_FORMATS = %w[IMAGE VIDEO DOCUMENT].freeze

  def initialize(endpoint:, catalog: nil)
    @endpoint = endpoint
    @catalog = catalog || Ibsoft::MetaTemplates::Catalog.new(endpoint.inbox)
  end

  def list
    @list ||= catalog
              .list
              .filter_map { |template| normalize(template) }
              .sort_by { |template| [template['name'].downcase, template['language'].downcase] }
  end

  def find(template_id)
    list.find { |template| template['id'] == template_id.to_s }
  end

  private

  attr_reader :endpoint, :catalog

  def normalize(source)
    template = source.to_h.deep_stringify_keys
    return unless eligible_template?(template)

    body_variables = component_variables(template, 'BODY')
    return if body_variables.many?
    return if unsupported_dynamic_components?(template)

    parameter_format = normalized_parameter_format(template)
    return unless valid_body_variable?(body_variables.first, parameter_format)

    {
      'id' => template['id'].to_s,
      'name' => template['name'].to_s,
      'language' => template['language'].to_s,
      'parameter_format' => parameter_format,
      'body_parameter' => body_parameter(body_variables.first, parameter_format)
    }
  end

  def eligible_template?(template)
    template['id'].present? &&
      template['name'].present? &&
      template['language'].present? &&
      template['status'].to_s.upcase == SUPPORTED_STATUS &&
      template['category'].to_s.upcase == SUPPORTED_CATEGORY &&
      template['sub_category'].to_s.upcase == SUPPORTED_SUB_CATEGORY
  end

  def normalized_parameter_format(template)
    value = template['parameter_format'].to_s.upcase
    value.in?(%w[NAMED POSITIONAL]) ? value : 'POSITIONAL'
  end

  def valid_body_variable?(variable, parameter_format)
    return true if variable.blank?
    return variable == '1' unless parameter_format == 'NAMED'

    variable.match?(Ibsoft::ExternalMessaging::OrderUpdateTemplateConfiguration::NAMED_PARAMETER_PATTERN)
  end

  def body_parameter(variable, parameter_format)
    return if variable.blank?

    {
      'format' => parameter_format.downcase,
      'key' => variable
    }
  end

  def unsupported_dynamic_components?(template)
    Array(template['components']).any? do |component_source|
      component = component_source.to_h.deep_stringify_keys
      type = component['type'].to_s.upcase

      next false if type == 'BODY'
      next true if type == 'HEADER' && MEDIA_HEADER_FORMATS.include?(component['format'].to_s.upcase)

      component_strings(component).any? { |value| variables_from(value).any? }
    end
  end

  def component_variables(template, type)
    component = Array(template['components']).find do |source|
      source.to_h.deep_stringify_keys['type'].to_s.upcase == type
    end
    return [] if component.blank?

    normalized = component.to_h.deep_stringify_keys
    variables = component_strings(normalized).flat_map { |value| variables_from(value) }
    named_examples = Array(normalized.dig('example', 'body_text_named_params')).filter_map do |example|
      example.to_h.deep_stringify_keys['param_name'].to_s.presence
    end

    (variables + named_examples).uniq
  end

  def component_strings(component)
    values = [component['text']]
    values.concat(Array(component['buttons']).flat_map do |button_source|
      button = button_source.to_h.deep_stringify_keys
      [button['url'], button['text']]
    end)
    values.compact
  end

  def variables_from(value)
    value.to_s.scan(VARIABLE_PATTERN).flatten.map(&:strip)
  end
end

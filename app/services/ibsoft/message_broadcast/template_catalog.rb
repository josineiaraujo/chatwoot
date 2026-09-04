class Ibsoft::MessageBroadcast::TemplateCatalog
  class UnsupportedInboxError < StandardError; end

  VARIABLE_PATTERN = /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/
  ORDER_DISPLAY_FORMATS = %w[ORDER_DETAILS].freeze
  ORDER_SUB_CATEGORIES = %w[ORDER_STATUS].freeze
  ORDER_BUTTON_TYPES = %w[ORDER_DETAILS].freeze
  MEDIA_HEADER_FORMATS = %w[IMAGE VIDEO DOCUMENT].freeze

  def initialize(inbox)
    @inbox = inbox
    @channel = inbox.channel
  end

  def call
    raise UnsupportedInboxError unless whatsapp_channel?

    sync_templates_from_provider
    normalize_templates
  end

  private

  attr_reader :channel

  def whatsapp_channel?
    channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud'
  end

  def sync_templates_from_provider
    channel.provider_service.sync_templates
  end

  def normalize_templates
    templates = channel.reload.message_templates.to_a.filter_map do |template|
      normalized_template = template.with_indifferent_access
      next if order_template?(normalized_template)

      normalize_template(normalized_template)
    end

    templates.sort_by { |template| [template[:name].to_s, template[:language].to_s] }
  end

  def order_template?(template)
    return true if ORDER_DISPLAY_FORMATS.include?(template[:display_format].to_s.upcase)
    return true if ORDER_SUB_CATEGORIES.include?(template[:sub_category].to_s.upcase)

    Array(template[:components]).any? do |component|
      buttons = component.with_indifferent_access[:buttons]
      Array(buttons).any? do |button|
        ORDER_BUTTON_TYPES.include?(button.with_indifferent_access[:type].to_s.upcase)
      end
    end
  end

  def normalize_template(template)
    components = normalize_components(template[:components])

    {
      id: template[:id].presence || "#{template[:name]}:#{template[:language]}",
      name: template[:name],
      language: template[:language],
      status: template[:status],
      category: template[:category],
      parameter_format: template[:parameter_format],
      components: components,
      variables: extract_variables(components)
    }
  end

  def normalize_components(components)
    Array(components).map do |component|
      normalized_component = component.with_indifferent_access

      {
        type: normalized_component[:type],
        format: normalized_component[:format],
        text: normalized_component[:text],
        example: normalized_component[:example],
        buttons: normalize_buttons(normalized_component[:buttons])
      }.compact
    end
  end

  def normalize_buttons(buttons)
    Array(buttons).map do |button|
      normalized_button = button.with_indifferent_access

      {
        type: normalized_button[:type],
        text: normalized_button[:text],
        url: normalized_button[:url],
        phone_number: normalized_button[:phone_number],
        example: normalized_button[:example]
      }.compact
    end
  end

  def extract_variables(components)
    variables = components.flat_map do |component|
      text_variables(component) + [media_header_variable(component)].compact
    end

    assign_storage_keys(variables)
  end

  def text_variables(component)
    return button_variables(component) if component[:type].to_s.upcase == 'BUTTONS'

    component_variable_keys(component).map do |parameter_key|
      {
        key: parameter_key,
        parameter_key: parameter_key,
        label: "{{#{parameter_key}}}",
        component_type: component[:type],
        parameter_type: 'text'
      }
    end
  end

  def button_variables(component)
    Ibsoft::MessageBroadcast::TemplateButtonVariables.new(component[:buttons]).call
  end

  def media_header_variable(component)
    component_type = component[:type].to_s.upcase
    media_type = component[:format].to_s.upcase
    return unless component_type == 'HEADER' && MEDIA_HEADER_FORMATS.include?(media_type)

    {
      key: 'header_media_url',
      parameter_key: 'media_url',
      label: 'header_media_url',
      component_type: 'HEADER',
      parameter_type: 'media',
      media_type: media_type.downcase
    }
  end

  def assign_storage_keys(variables)
    key_counts = variables.each_with_object(Hash.new(0)) do |variable, counts|
      counts[variable[:parameter_key]] += 1
    end

    scoped_variables = variables.map do |variable|
      storage_key = variable[:key]
      if variable[:component_type] != 'BUTTONS' && key_counts[variable[:parameter_key]] > 1
        storage_key = "#{variable[:component_type].to_s.downcase}:#{variable[:parameter_key]}"
      end

      variable.merge(key: storage_key)
    end

    scoped_variables.sort_by { |variable| variable_sort_value(variable) }
  end

  def variable_sort_value(variable)
    component_order = %w[HEADER BODY FOOTER BUTTONS].index(variable[:component_type].to_s.upcase) || 4
    button_order = variable[:button_index].presence || -1
    [component_order, button_order, natural_sort_value(variable[:parameter_key])]
  end

  def component_variable_keys(component)
    extracted_keys = template_strings(component).flat_map do |value|
      value.to_s.scan(VARIABLE_PATTERN).flatten
    end

    (extracted_keys + example_variable_keys(component)).uniq
  end

  def template_strings(component)
    [component[:text]].compact
  end

  def example_variable_keys(component)
    example = component[:example]
    return [] if example.blank?

    [
      example['body_text_named_params'],
      example['header_text_named_params']
    ].flatten.compact.pluck('param_name').compact
  end

  def natural_sort_value(key)
    key.to_s.match?(/\A\d+\z/) ? [0, key.to_i] : [1, key.to_s]
  end
end

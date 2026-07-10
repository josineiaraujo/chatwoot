class Ibsoft::MessageBroadcast::TemplateCatalog
  class UnsupportedInboxError < StandardError; end

  VARIABLE_PATTERN = /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/

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
    templates = channel.provider_service.fetch_whatsapp_templates(meta_templates_url)
    channel.update!(message_templates: templates, message_templates_last_updated: Time.current)
  end

  def normalize_templates
    templates = channel.reload.message_templates.to_a.map do |template|
      normalize_template(template.with_indifferent_access)
    end

    templates.sort_by { |template| [template[:name].to_s, template[:language].to_s] }
  end

  def normalize_template(template)
    components = normalize_components(template[:components])

    {
      id: template[:id].presence || "#{template[:name]}:#{template[:language]}",
      name: template[:name],
      language: template[:language],
      status: template[:status],
      category: template[:category],
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
        phone_number: normalized_button[:phone_number]
      }.compact
    end
  end

  def extract_variables(components)
    variables = {}

    components.each do |component|
      component_variable_keys(component).each do |key|
        variables[key] ||= {
          key: key,
          label: "{{#{key}}}",
          component_type: component[:type]
        }
      end
    end

    variables.values.sort_by { |variable| natural_sort_value(variable[:key]) }
  end

  def component_variable_keys(component)
    extracted_keys = template_strings(component).flat_map do |value|
      value.to_s.scan(VARIABLE_PATTERN).flatten
    end

    (extracted_keys + example_variable_keys(component)).uniq
  end

  def template_strings(component)
    [
      component[:text],
      component[:buttons]&.flat_map { |button| [button[:text], button[:url]] }
    ].flatten.compact
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

  def meta_templates_url
    business_account_id = channel.provider_config['business_account_id']
    api_key = channel.provider_config['api_key']

    "#{api_base_path}/v14.0/#{business_account_id}/message_templates?access_token=#{api_key}"
  end

  def api_base_path
    ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
  end
end

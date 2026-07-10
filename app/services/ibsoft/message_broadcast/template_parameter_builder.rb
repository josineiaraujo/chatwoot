class Ibsoft::MessageBroadcast::TemplateParameterBuilder
  COMPONENT_KEYS = {
    'HEADER' => 'header',
    'BODY' => 'body',
    'FOOTER' => 'footer'
  }.freeze

  def initialize(broadcast:, recipient:)
    @broadcast = broadcast
    @recipient = recipient
  end

  def call
    {
      'name' => broadcast.template_name,
      'language' => broadcast.template_language,
      'processed_params' => processed_params
    }
  end

  private

  attr_reader :broadcast, :recipient

  def processed_params
    broadcast.template_variables.each_with_object({}) do |(key, config), params|
      value = value_for(key, config)
      next if value.blank?

      component_key = component_key_for(config)
      if component_key == 'buttons'
        params['buttons'] ||= []
        params['buttons'] << button_parameter(config, value)
      else
        params[component_key] ||= {}
        params[component_key][key.to_s] = value
      end
    end
  end

  def value_for(key, config)
    return config['value'].to_s if config['type'] == 'fixed'

    recipient.template_variable_values[key.to_s].presence || recipient_field(config['field'])
  end

  def recipient_field(field)
    case field
    when 'name', 'customer_name'
      recipient.customer_name
    when 'primary_phone'
      recipient.primary_phone
    when 'fallback_phone'
      recipient.fallback_phone
    when 'phone_used'
      recipient.phone_used
    end.to_s
  end

  def component_key_for(config)
    component_type = config['component_type'].to_s.upcase
    return 'buttons' if component_type == 'BUTTONS'

    COMPONENT_KEYS.fetch(component_type, 'body')
  end

  def button_parameter(config, value)
    {
      'type' => config['button_type'].presence || 'url',
      'parameter' => value
    }
  end
end

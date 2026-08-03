class Ibsoft::MessageBroadcast::TemplateParameterBuilder
  COMPONENT_KEYS = {
    'HEADER' => 'header',
    'BODY' => 'body',
    'FOOTER' => 'footer'
  }.freeze
  MEDIA_TYPES = %w[image video document].freeze
  STATIC_BUTTON_SLOT_TYPE = 'ibsoft_static_placeholder'.freeze

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
    params = broadcast.template_variables.each_with_object({}) do |(key, config), result|
      value = value_for(key, config)
      next if value.blank?

      component_key = component_key_for(config)
      if media_header?(config)
        assign_media_header(result, config, value)
      elsif component_key == 'buttons'
        assign_button_parameter(result, config, value)
      else
        result[component_key] ||= {}
        result[component_key][parameter_key_for(key, config)] = value
      end
    end

    fill_static_button_slots(params)
    params
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

  def parameter_key_for(storage_key, config)
    config['parameter_key'].presence || storage_key.to_s
  end

  def media_header?(config)
    config['component_type'].to_s.upcase == 'HEADER' && config['parameter_type'] == 'media'
  end

  def assign_media_header(params, config, value)
    media_type = config['media_type'].to_s.downcase
    return unless MEDIA_TYPES.include?(media_type)

    params['header'] ||= {}
    params['header']['media_url'] = value
    params['header']['media_type'] = media_type
  end

  def assign_button_parameter(params, config, value)
    params['buttons'] ||= []
    index = button_index(config)

    if index.nil?
      params['buttons'] << button_parameter(config, value)
    else
      params['buttons'][index] = button_parameter(config, value)
    end
  end

  # Chatwoot validates every array position before processing buttons. Keep
  # static positions explicit so dynamic buttons retain their Meta indexes.
  def fill_static_button_slots(params)
    return if params['buttons'].blank?

    params['buttons'].map! do |button|
      button || { 'type' => STATIC_BUTTON_SLOT_TYPE }
    end
  end

  def button_index(config)
    return if config['button_index'].blank?

    index = Integer(config['button_index'])
    raise ArgumentError, 'Button index must be between 0 and 9' unless index.between?(0, 9)

    index
  rescue TypeError, ArgumentError
    raise ArgumentError, 'Button index must be between 0 and 9'
  end

  def button_parameter(config, value)
    {
      'type' => config['button_type'].presence&.downcase || 'url',
      'parameter' => value
    }
  end
end

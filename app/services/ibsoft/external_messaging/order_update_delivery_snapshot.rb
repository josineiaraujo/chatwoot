class Ibsoft::ExternalMessaging::OrderUpdateDeliverySnapshot
  def initialize(endpoint:, command:)
    @endpoint = endpoint
    @command = command.to_h.symbolize_keys
  end

  def call
    return interactive_snapshot if endpoint.order_update_delivery_mode == 'interactive'

    template_snapshot
  end

  private

  attr_reader :endpoint, :command

  def interactive_snapshot
    {
      delivery_method: 'interactive',
      template_name: nil,
      template_language: nil,
      template_components: []
    }
  end

  def template_snapshot
    descriptor = template_descriptor
    raise_error unless valid_descriptor?(descriptor)

    {
      delivery_method: 'template',
      template_name: descriptor['name'],
      template_language: descriptor['language'],
      template_components: template_components(descriptor['body_parameter'])
    }
  end

  def template_descriptor
    settings = endpoint.order_update_template_settings.to_h.deep_stringify_keys
    key = Ibsoft::ExternalMessaging::OrderUpdateEventKey.call(
      order_status: command[:order_status],
      payment_status: command[:payment_status]
    )
    settings.dig('overrides', key) || settings['default']
  end

  def valid_descriptor?(descriptor)
    descriptor.is_a?(Hash) && descriptor['name'].present? && descriptor['language'].present?
  end

  def template_components(parameter)
    return [] if parameter.blank?

    text_parameter = {
      type: 'text',
      text: command[:message_content]
    }
    text_parameter[:parameter_name] = parameter['key'] if parameter['format'] == 'named'

    [
      {
        type: 'body',
        parameters: [text_parameter]
      }
    ]
  end

  def raise_error
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(
      'order_update_template_not_configured',
      http_status: :unprocessable_entity
    )
  end
end

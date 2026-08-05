class Ibsoft::ExternalMessaging::MetaClient
  Result = Struct.new(:message_id, :http_status, keyword_init: true)

  class Error < StandardError
    attr_reader :code, :http_status

    def initialize(message, code:, http_status:)
      @code = code
      @http_status = http_status
      super(message)
    end
  end

  def initialize(delivery: nil, order_update: nil)
    @delivery = delivery
    @order_update = order_update
    raise ArgumentError, 'provide exactly one external message record' if [delivery, order_update].compact.size != 1

    @channel = record.inbox.channel
  end

  def send_template
    validate_channel!
    response = HTTParty.post(
      messages_url,
      headers: request_headers,
      body: request_body.to_json,
      timeout: timeout_seconds
    )
    parse_response(response)
  end

  def send_order_status
    validate_channel!
    response = HTTParty.post(
      messages_url,
      headers: request_headers,
      body: order_status_request_body.to_json,
      timeout: timeout_seconds
    )
    parse_response(response)
  end

  private

  attr_reader :delivery, :order_update, :channel

  def record
    delivery || order_update
  end

  def validate_channel!
    valid = channel.is_a?(Channel::Whatsapp) &&
            channel.provider == 'whatsapp_cloud' &&
            channel.provider_config['api_key'].present? &&
            channel.provider_config['phone_number_id'].present?
    return if valid

    raise Error.new(
      I18n.t('ibsoft_external_messaging.errors.invalid_channel'),
      code: 'invalid_channel',
      http_status: nil
    )
  end

  def messages_url
    base_url = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com').delete_suffix('/')
    version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
    "#{base_url}/#{version}/#{channel.provider_config['phone_number_id']}/messages"
  end

  def request_headers
    {
      'Authorization' => "Bearer #{channel.provider_config['api_key']}",
      'Content-Type' => 'application/json'
    }
  end

  def request_body
    {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: delivery.recipient,
      type: 'template',
      template: template_payload
    }
  end

  def template_payload
    {
      name: delivery.template_name,
      language: {
        policy: 'deterministic',
        code: delivery.template_language
      }
    }.tap do |template|
      components = materialized_template_components
      template[:components] = components if components.present?
    end
  end

  def materialized_template_components
    Ibsoft::ExternalMessaging::OrderPixSecret.materialize(
      components: delivery.template_components,
      key: delivery.order_pix_key
    )
  rescue Ibsoft::ExternalMessaging::OrderPixSecret::MissingKey
    raise Error.new(
      I18n.t('ibsoft_external_messaging.errors.pix_key_missing'),
      code: 'pix_key_missing',
      http_status: nil
    )
  end

  def order_status_request_body
    parameters = {
      reference_id: order_update.order.reference_id
    }
    parameters[:order] = order_parameters if order_update.order_status.present?
    parameters[:payment] = payment_parameters if order_update.payment_status.present?

    {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: order_update.order.recipient,
      type: 'interactive',
      interactive: {
        type: 'order_status',
        body: { text: order_update.message_content },
        action: {
          name: 'review_order',
          parameters: parameters
        }
      }
    }
  end

  def order_parameters
    parameters = { status: order_update.order_status }
    parameters[:description] = order_update.description if order_update.description.present?
    parameters
  end

  def payment_parameters
    parameters = { status: order_update.payment_status }
    parameters[:timestamp] = order_update.payment_timestamp if order_update.payment_timestamp.present?
    parameters
  end

  def timeout_seconds
    ENV.fetch('IBSOFT_EXTERNAL_MESSAGING_META_TIMEOUT_SECONDS', 20).to_i.clamp(5, 60)
  end

  def parse_response(response)
    parsed = parsed_response(response)
    message_id = message_id_from(parsed)
    return Result.new(message_id: message_id, http_status: response.code) if response.success? && message_id.present?

    raise_meta_error(parsed, response.code)
  end

  def parsed_response(response)
    response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
  end

  def message_id_from(parsed)
    parsed.dig('messages', 0, 'id').to_s
  end

  def raise_meta_error(parsed, http_status)
    error = parsed['error'].is_a?(Hash) ? parsed['error'] : {}
    raise Error.new(
      error['error_user_msg'].presence || error['message'].presence || I18n.t('ibsoft_external_messaging.errors.meta_rejected'),
      code: error['code'].presence&.to_s || 'meta_rejected',
      http_status: http_status
    )
  end
end

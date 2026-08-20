class Ibsoft::ExternalMessaging::MetaClient
  ERROR_MESSAGE_MAX_LENGTH = 2000

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
    send_request(request_body)
  end

  def send_order_update
    validate_channel!
    send_request(Ibsoft::ExternalMessaging::OrderUpdatePayloadBuilder.new(update: order_update).call)
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

  def send_request(body)
    response = HTTParty.post(
      messages_url,
      headers: request_headers,
      body: body.to_json,
      timeout: timeout_seconds
    )
    parse_response(response)
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
    template_payload_for(
      name: delivery.template_name,
      language: delivery.template_language,
      components: materialized_template_components
    )
  end

  def template_payload_for(name:, language:, components:)
    {
      name: name,
      language: {
        policy: 'deterministic',
        code: language
      }
    }.tap do |template|
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
      meta_error_message(error),
      code: error['code'].presence&.to_s || 'meta_rejected',
      http_status: http_status
    )
  end

  def meta_error_message(error)
    return legacy_meta_error_message(error) unless record.endpoint.failure_diagnostics_enabled?

    messages = [
      error['error_user_title'],
      error['error_user_msg'],
      error['message'],
      error.dig('error_data', 'details')
    ].filter_map { |value| normalized_error_text(value) }.uniq

    messages = [I18n.t('ibsoft_external_messaging.errors.meta_rejected')] if messages.empty?
    messages.join(' - ').truncate(ERROR_MESSAGE_MAX_LENGTH)
  end

  def legacy_meta_error_message(error)
    error['error_user_msg'].presence ||
      error['message'].presence ||
      I18n.t('ibsoft_external_messaging.errors.meta_rejected')
  end

  def normalized_error_text(value)
    value.to_s.squish.presence
  end
end

class Ibsoft::MessageBroadcast::MetaTemplateClient
  Result = Data.define(:message_id, :http_status)

  class Error < StandardError
    attr_reader :code, :http_status

    def initialize(message, code:, http_status: nil)
      @code = code
      @http_status = http_status
      super(message)
    end

    def fallback_eligible? = false
  end

  class RejectedError < Error
    def fallback_eligible? = http_status.to_i.between?(400, 499)
  end

  class UncertainError < Error; end
  class ConfigurationError < Error; end

  def initialize(broadcast:, recipient:, message: nil)
    @broadcast = broadcast
    @recipient = recipient
    @message = message
    @channel = broadcast.inbox.channel
  end

  def call(phone_candidate)
    validate_channel!
    template = processed_template
    body = request_body(phone_candidate, template).to_json
    @request_started = true
    response = HTTParty.post(
      messages_url,
      headers: request_headers,
      body: body,
      timeout: timeout_seconds
    )
    parse_response(response)
  rescue Error
    raise
  rescue StandardError => e
    raise e unless @request_started

    raise UncertainError.new(
      I18n.t('ibsoft.message_broadcast.errors.delivery_result_uncertain'),
      code: 'delivery_result_uncertain'
    )
  end

  private

  attr_reader :broadcast, :recipient, :message, :channel

  def validate_channel!
    valid = channel.is_a?(Channel::Whatsapp) &&
            channel.provider == 'whatsapp_cloud' &&
            channel.provider_config['api_key'].present? &&
            channel.provider_config['phone_number_id'].present?
    return if valid

    raise ConfigurationError.new(
      I18n.t('ibsoft.message_broadcast.errors.invalid_channel'),
      code: 'invalid_channel'
    )
  end

  def processed_template
    name, _namespace, language, components = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: template_params,
      message: message
    ).call

    if name.blank? || language.blank? || components.nil?
      raise ConfigurationError.new(
        I18n.t('ibsoft.message_broadcast.errors.template_not_found'),
        code: 'template_not_found'
      )
    end

    { name: name, language: language, components: components }
  end

  def template_params
    @template_params ||= Ibsoft::MessageBroadcast::TemplateParameterBuilder.new(
      broadcast: broadcast,
      recipient: recipient
    ).call
  end

  def messages_url
    base_url = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com').delete_suffix('/')
    api_version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
    "#{base_url}/#{api_version}/#{channel.provider_config['phone_number_id']}/messages"
  end

  def request_headers
    {
      'Authorization' => "Bearer #{channel.provider_config['api_key']}",
      'Content-Type' => 'application/json'
    }
  end

  def request_body(phone_candidate, template)
    {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: phone_candidate.source_id,
      type: 'template',
      template: {
        name: template[:name],
        language: { policy: 'deterministic', code: template[:language] },
        components: template[:components]
      }
    }
  end

  def timeout_seconds
    ENV.fetch('IBSOFT_MESSAGE_BROADCAST_META_TIMEOUT_SECONDS', 20).to_i.clamp(5, 60)
  end

  def parse_response(response)
    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    message_id = parsed.dig('messages', 0, 'id').to_s
    return Result.new(message_id: message_id, http_status: response.code) if response.success? && message_id.present?

    raise_response_error(parsed, response.code)
  end

  def raise_response_error(parsed, http_status)
    message_text, error_code = response_error_details(parsed)

    if uncertain_http_status?(http_status)
      raise UncertainError.new(
        message_text || I18n.t('ibsoft.message_broadcast.errors.delivery_result_uncertain'),
        code: 'delivery_result_uncertain',
        http_status: http_status
      )
    end

    raise RejectedError.new(
      message_text || I18n.t('ibsoft.message_broadcast.errors.meta_rejected'),
      code: error_code,
      http_status: http_status
    )
  end

  def response_error_details(parsed)
    error = parsed['error'].is_a?(Hash) ? parsed['error'] : {}
    message = error['error_user_msg'].presence || error['message'].presence
    [message, error['code'].presence&.to_s || 'meta_rejected']
  end

  def uncertain_http_status?(http_status)
    status = http_status.to_i
    status >= 500 || status.between?(200, 299)
  end
end

class Ibsoft::MetaTemplates::Client
  TEMPLATE_FIELDS = %w[
    id
    name
    status
    category
    sub_category
    display_format
    language
    parameter_format
    components
    rejected_reason
    quality_score
    last_updated_time
  ].join(',').freeze
  MAX_PAGES = 100

  class Error < StandardError
    attr_reader :code, :http_status

    def initialize(message, code: 'meta_error', http_status: nil)
      @code = code
      @http_status = http_status
      super(message)
    end
  end

  def initialize(channel)
    @channel = channel
    validate_channel!
  end

  def list_templates
    templates = []
    after = nil

    MAX_PAGES.times do
      query = { fields: TEMPLATE_FIELDS, limit: 100 }
      query[:after] = after if after.present?
      response = request(:get, templates_path, query: query)
      templates.concat(Array(response['data']))
      after = response.dig('paging', 'cursors', 'after')
      break if after.blank? || response.dig('paging', 'next').blank?
    end

    templates
  end

  def template(template_id)
    request(:get, "/#{safe_identifier(template_id)}", query: { fields: TEMPLATE_FIELDS })
  end

  def create_template(payload)
    request(:post, templates_path, body: payload)
  end

  def update_template(template_id, payload)
    request(:post, "/#{safe_identifier(template_id)}", body: payload)
  end

  def delete_template(template_id)
    request(:delete, templates_path, query: { hsm_id: safe_identifier(template_id) })
  end

  private

  attr_reader :channel

  def validate_channel!
    valid = channel.is_a?(Channel::Whatsapp) &&
            channel.provider == 'whatsapp_cloud' &&
            access_token.present? &&
            business_account_id.present?
    return if valid

    raise Error.new(
      I18n.t('ibsoft_meta_templates.errors.invalid_credentials'),
      code: 'invalid_credentials',
      http_status: :unprocessable_entity
    )
  end

  def request(method, path, query: nil, body: nil)
    response = execute_request(method, path, query, body)
    parsed = parsed_response(response)
    return parsed if response.success?

    raise_response_error(parsed, response.code)
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise Error.new(
      I18n.t('ibsoft_meta_templates.errors.timeout'),
      code: 'timeout',
      http_status: :gateway_timeout
    )
  rescue SocketError, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError
    raise Error.new(
      I18n.t('ibsoft_meta_templates.errors.unavailable'),
      code: 'unavailable',
      http_status: :bad_gateway
    )
  end

  def execute_request(method, path, query, body)
    HTTParty.public_send(
      method,
      "#{api_base_url}#{path}",
      headers: request_headers,
      query: query,
      body: body&.to_json,
      timeout: timeout_seconds
    )
  end

  def parsed_response(response)
    response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
  end

  def raise_response_error(parsed, http_status)
    error = parsed['error'].is_a?(Hash) ? parsed['error'] : {}
    code = error['code'].presence&.to_s || 'meta_error'
    message = error['error_user_msg'].presence ||
              error['message'].presence ||
              I18n.t('ibsoft_meta_templates.errors.meta_rejected')

    raise Error.new(message, code: code, http_status: http_status)
  end

  def safe_identifier(value)
    identifier = value.to_s
    return identifier if identifier.match?(/\A[a-zA-Z0-9:_-]+\z/)

    raise Error.new(
      I18n.t('ibsoft_meta_templates.errors.invalid_template'),
      code: 'invalid_template',
      http_status: :unprocessable_entity
    )
  end

  def templates_path
    "/#{business_account_id}/message_templates"
  end

  def business_account_id
    channel.provider_config['business_account_id'].to_s
  end

  def access_token
    channel.provider_config['api_key'].to_s
  end

  def api_base_url
    base = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com').delete_suffix('/')
    version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
    "#{base}/#{version}"
  end

  def request_headers
    {
      'Authorization' => "Bearer #{access_token}",
      'Content-Type' => 'application/json'
    }
  end

  def timeout_seconds
    ENV.fetch('IBSOFT_META_TEMPLATES_TIMEOUT_SECONDS', 20).to_i.clamp(5, 60)
  end
end

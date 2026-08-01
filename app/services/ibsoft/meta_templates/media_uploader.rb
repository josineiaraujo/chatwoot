require 'net/http'

class Ibsoft::MetaTemplates::MediaUploader
  UPLOAD_SESSION_ID_PATTERN = /\Aupload:[A-Za-z0-9:_-]+={0,2}(?:\?sig=[A-Za-z0-9._~-]+)?\z/

  CONTENT_LIMITS = {
    'image/jpeg' => 5.megabytes,
    'image/png' => 5.megabytes,
    'video/mp4' => 16.megabytes,
    'application/pdf' => 100.megabytes
  }.freeze

  class Error < StandardError
    attr_reader :code

    def initialize(message, code:)
      @code = code
      super(message)
    end
  end

  def initialize(channel:, file:)
    @channel = channel
    @file = file
  end

  def call
    validate!
    session_id = create_upload_session
    handle = upload_file(session_id)

    {
      handle: handle,
      filename: file.original_filename,
      content_type: file.content_type,
      size: file.size
    }
  end

  private

  attr_reader :channel, :file

  def validate!
    limit = CONTENT_LIMITS[file.content_type]
    raise_upload_error(:unsupported_file) if limit.blank?
    raise_upload_error(:file_too_large) if file.size.to_i > limit
    raise_upload_error(:missing_app_id) if app_id.blank?
    raise_upload_error(:invalid_credentials) if access_token.blank?
  end

  def create_upload_session
    response = HTTParty.post(
      "#{api_base_url}/#{app_id}/uploads",
      headers: authorization_headers,
      query: {
        file_name: file.original_filename,
        file_length: file.size,
        file_type: file.content_type
      },
      timeout: timeout_seconds
    )
    parsed = parse_response(response)
    parsed['id'].presence || raise_upload_error(:session_failed)
  end

  def upload_file(session_id)
    uri = URI("#{api_base_url}/#{safe_session_id(session_id)}")
    request = upload_request(uri)

    File.open(file.tempfile.path, 'rb') do |stream|
      perform_upload(uri, request, stream)
    rescue JSON::ParserError
      raise_upload_error(:upload_failed)
    end
  end

  def upload_request(uri)
    request = Net::HTTP::Post.new(uri)
    authorization_headers.merge(
      'Content-Type' => file.content_type,
      'file_offset' => '0'
    ).each { |key, value| request[key] = value }
    request
  end

  def perform_upload(uri, request, stream)
    request.body_stream = stream
    request.content_length = file.size
    response = perform_request(uri, request)
    parsed = JSON.parse(response.body)
    return parsed['h'] if response.is_a?(Net::HTTPSuccess) && parsed['h'].present?

    raise_upload_error(:upload_failed)
  end

  def perform_request(uri, request)
    Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == 'https',
      open_timeout: timeout_seconds,
      read_timeout: timeout_seconds
    ) { |http| http.request(request) }
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise_upload_error(:timeout)
  rescue SocketError, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError
    raise_upload_error(:unavailable)
  end

  def parse_response(response)
    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    return parsed if response.success?

    raise_upload_error(:session_failed)
  end

  def safe_session_id(value)
    session_id = value.to_s
    return session_id if session_id.match?(UPLOAD_SESSION_ID_PATTERN)

    raise_upload_error(:session_failed)
  end

  def authorization_headers
    { 'Authorization' => "OAuth #{access_token}" }
  end

  def access_token
    channel.provider_config['api_key'].to_s
  end

  def app_id
    GlobalConfigService.load('WHATSAPP_APP_ID', '').to_s
  end

  def api_base_url
    base = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com').delete_suffix('/')
    version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
    "#{base}/#{version}"
  end

  def timeout_seconds
    ENV.fetch('IBSOFT_META_TEMPLATES_UPLOAD_TIMEOUT_SECONDS', 60).to_i.clamp(10, 180)
  end

  def raise_upload_error(code)
    raise Error.new(
      I18n.t("ibsoft_meta_templates.errors.#{code}"),
      code: code.to_s
    )
  end
end

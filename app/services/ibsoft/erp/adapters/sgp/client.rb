require 'base64'

class Ibsoft::Erp::Adapters::Sgp::Client
  DEFAULT_TIMEOUT_SECONDS = 20

  Response = Struct.new(:status, :total, :records, :payload, keyword_init: true) do
    def success?
      status.to_i.between?(200, 299)
    end
  end

  class RequestError < StandardError
    attr_reader :status

    def initialize(message, status: nil)
      @status = status
      super(message)
    end
  end

  def initialize(connection, timeout: DEFAULT_TIMEOUT_SECONDS)
    @connection = connection
    @timeout = timeout
  end

  attr_reader :connection

  def customers(payload = {})
    parsed = request(:post, 'api/ura/clientes/', payload: payload, format: :form)
    pagination = parsed.fetch('paginacao', {})

    response(parsed, records: parsed['clientes'], total: pagination['total'])
  end

  def plans(pop: nil)
    parsed = request(:get, 'api/ura/consultaplano/', payload: {}, query: { pop: pop }.compact, format: :json)
    response(parsed, records: parsed['planos'], total: parsed['total_planos'])
  end

  def pops
    parsed = request(:post, 'api/ura/pops/', payload: {}, format: :form)
    response(parsed, records: parsed, total: Array(parsed).size)
  end

  def nas
    parsed = request(:post, 'api/ura/nas/list/', payload: {}, format: :json)
    response(parsed, records: parsed, total: Array(parsed).size)
  end

  def pppoe(payload = {})
    parsed = request(:post, 'ws/radius/radacct/list/all/', payload: payload, format: :form)
    pagination = parsed.fetch('paggination', {})

    response(parsed, records: parsed['result'], total: pagination['total'])
  end

  private

  attr_reader :timeout

  def request(method, path, payload:, format:, query: {})
    options = {
      headers: request_headers(format),
      timeout: timeout
    }
    options[:query] = query if query.present?
    options[:body] = serialized_body(authenticated_payload(payload), format)

    http_response = HTTParty.public_send(method, endpoint_url(path), options)
    parse_response(http_response)
  end

  def authenticated_payload(payload)
    result = payload.to_h.compact.deep_stringify_keys
    return result if connection.auth_type == 'basic'

    result.merge(
      'app' => credentials[:app],
      'token' => credentials[:token]
    )
  end

  def serialized_body(payload, format)
    format == :json ? payload.to_json : payload
  end

  def request_headers(format)
    headers = { 'Accept' => 'application/json' }
    headers['Content-Type'] = 'application/json' if format == :json
    headers['Authorization'] = basic_auth_header if connection.auth_type == 'basic'
    headers
  end

  def basic_auth_header
    encoded_credentials = Base64.strict_encode64(
      "#{credentials[:username]}:#{credentials[:password]}"
    )

    "Basic #{encoded_credentials}"
  end

  def credentials
    @credentials ||= connection.credentials.to_h.with_indifferent_access
  end

  def endpoint_url(path)
    "#{endpoint_root}/#{path.delete_prefix('/')}"
  end

  def endpoint_root
    @endpoint_root ||= connection.base_url.to_s.delete_suffix('/')
                                 .delete_suffix('/api/ura')
                                 .delete_suffix('/api')
  end

  def parse_response(http_response)
    status = http_response.code.to_i
    raise RequestError.new('SGP request failed', status: status) unless status.between?(200, 299)

    JSON.parse(http_response.body.to_s)
  rescue JSON::ParserError => e
    raise RequestError, "Invalid SGP JSON response: #{e.message}"
  end

  def response(payload, records:, total:)
    Response.new(
      status: 200,
      total: total.to_i,
      records: Array(records),
      payload: payload
    )
  end
end

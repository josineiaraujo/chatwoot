require 'base64'

class Ibsoft::Erp::Adapters::Ixc::Client
  DEFAULT_TIMEOUT_SECONDS = 20

  Response = Struct.new(:status, :total, :records, keyword_init: true) do
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

  def list(table, payload)
    response = HTTParty.get(
      endpoint_url(table),
      headers: headers,
      body: payload.to_json,
      timeout: @timeout
    )

    parsed_response = parse_response(response)
    Response.new(
      status: response.code.to_i,
      total: parsed_response['total'].to_i,
      records: Array(parsed_response['registros'])
    )
  end

  private

  attr_reader :connection

  def endpoint_url(table)
    "#{endpoint_base}/#{table}"
  end

  def endpoint_base
    base_url = connection.base_url.to_s.delete_suffix('/')
    return base_url if base_url.end_with?('/webservice/v1')

    "#{base_url}/webservice/v1"
  end

  def headers
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'Authorization' => basic_auth_header,
      'ixcsoft' => 'listar'
    }
  end

  def basic_auth_header
    credentials = connection.credentials.to_h.with_indifferent_access
    encoded_credentials = Base64.strict_encode64(
      "#{credentials[:username]}:#{credentials[:password]}"
    )

    "Basic #{encoded_credentials}"
  end

  def parse_response(response)
    raise RequestError.new('IXC request failed', status: response.code.to_i) unless response.code.to_i.between?(200, 299)

    JSON.parse(response.body.to_s)
  rescue JSON::ParserError => e
    raise RequestError, "Invalid IXC JSON response: #{e.message}"
  end
end

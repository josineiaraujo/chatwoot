class Ibsoft::BusinessCalendar::InvertextoClient
  BASE_URL = 'https://api.invertexto.com/v1/holidays'.freeze
  REQUEST_TIMEOUT = 15

  class RequestError < StandardError; end

  def initialize(token: ENV.fetch('IBSOFT_INVERTEXTO_HOLIDAYS_TOKEN', nil))
    @token = token
  end

  def holidays(year:, state_code: nil)
    raise RequestError, 'missing_token' if token.blank?

    response = HTTParty.get(
      "#{BASE_URL}/#{Integer(year)}",
      headers: { 'Authorization' => "Bearer #{token}" },
      query: state_query(state_code),
      timeout: REQUEST_TIMEOUT
    )
    raise RequestError, "http_#{response.code}" unless response.success?

    Array(response.parsed_response)
  rescue ArgumentError, TypeError
    raise RequestError, 'invalid_year'
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    raise RequestError, e.class.name.underscore
  end

  private

  attr_reader :token

  def state_query(state_code)
    normalized_state = state_code.to_s.upcase.presence
    normalized_state ? { state: normalized_state } : {}
  end
end

class Ibsoft::ExternalMessaging::OrderUpdateCredentials
  MAX_AUTHORIZATION_BYTES = 4.kilobytes

  def initialize(method:, authorization:, query_parameters:)
    @method = method.to_s.upcase
    @authorization = authorization.to_s
    @query_parameters = query_parameters.to_h.stringify_keys
  end

  def call
    token_credentials
  end

  private

  attr_reader :method, :authorization, :query_parameters

  def token_credentials
    bearer = authorization.match(/\ABearer\s+(.+)\z/i) if authorization.bytesize <= MAX_AUTHORIZATION_BYTES
    token = bearer&.[](1)&.strip
    token = query_parameters['token'].to_s.strip if token.blank? && method == 'GET'
    { token: token.presence }
  end
end

class Ibsoft::ExternalMessaging::OrderUpdateInboundRequest
  Result = Struct.new(:credentials, :fields, :recipient, keyword_init: true)

  def initialize(family:, request_attributes:)
    @family = family.to_s
    @method = request_attributes.fetch(:method, '').to_s
    @authorization = request_attributes.fetch(:authorization, '').to_s
    @query_parameters = request_attributes.fetch(:query_parameters, {}).to_h
    @raw_body = request_attributes.fetch(:raw_body, '').to_s
    @media_type = request_attributes.fetch(:media_type, '').to_s
    @content_type = request_attributes.fetch(:content_type, '').to_s
  end

  def call
    return ixc_request if family == 'ixc'
    return standard_request if family == 'standard'

    sgp_request
  end

  private

  attr_reader :family, :method, :authorization, :query_parameters, :raw_body,
              :media_type, :content_type

  def ixc_request
    parsed = Ibsoft::ExternalMessaging::IxcInboundRequestParser.new(
      method: method,
      query_parameters: query_parameters,
      raw_body: raw_body,
      content_type: content_type
    ).call

    Result.new(
      credentials: parsed.fetch(:credentials),
      fields: parsed.fetch(:fields),
      recipient: parsed.fetch(:recipient)
    )
  end

  def sgp_request
    Result.new(
      credentials: Ibsoft::ExternalMessaging::OrderUpdateCredentials.new(
        method: method,
        authorization: authorization,
        query_parameters: query_parameters
      ).call,
      fields: Ibsoft::ExternalMessaging::OrderStatusRequestParser.new(
        method: method,
        media_type: media_type,
        raw_body: raw_body,
        query_parameters: query_parameters
      ).call
    )
  end

  def standard_request
    validate_standard_request!

    Result.new(
      credentials: Ibsoft::ExternalMessaging::OrderUpdateCredentials.new(
        method: method,
        authorization: authorization,
        query_parameters: {}
      ).call,
      fields: Ibsoft::ExternalMessaging::OrderStatusRequestParser.new(
        method: method,
        media_type: media_type,
        raw_body: validated_standard_body,
        query_parameters: {}
      ).call
    )
  end

  def validate_standard_request!
    raise_error('standard_method_not_allowed', http_status: :method_not_allowed) unless method.upcase == 'POST'
    return if media_type.downcase == 'text/plain'

    raise_error('standard_content_type_invalid', http_status: :unsupported_media_type)
  end

  def validated_standard_body
    payload = raw_body.dup.force_encoding(Encoding::UTF_8)
    raise_error('payload_invalid_encoding') unless payload.valid_encoding?

    payload = payload.strip
    raise_error('payload_invalid_format') unless payload.start_with?('[')
    raise_error('payload_invalid_separator') if payload.gsub('||', '').include?('|')

    payload
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end

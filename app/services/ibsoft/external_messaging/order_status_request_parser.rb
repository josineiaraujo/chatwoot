class Ibsoft::ExternalMessaging::OrderStatusRequestParser
  MAX_REQUEST_BYTES = 64.kilobytes

  def initialize(method:, media_type:, raw_body:, query_parameters:)
    @method = method.to_s.upcase
    @media_type = media_type.to_s.downcase
    @raw_body = raw_body.to_s
    @query_parameters = query_parameters.to_h.deep_stringify_keys
  end

  def call
    return parse_query if method == 'GET'
    return parse_body if method == 'POST'

    raise_error('order_update_method_not_allowed', http_status: :method_not_allowed)
  end

  private

  attr_reader :method, :media_type, :raw_body, :query_parameters

  def parse_query
    fields = query_parameters.except(
      'token',
      'controller',
      'action',
      'format',
      'ibsoft_external_messaging_family',
      'ibsoft_external_messaging_instance_type'
    )
    validate_size!(fields.sum { |name, value| name.to_s.bytesize + scalar_value(value).bytesize })
    normalize_scalar_fields(fields)
  end

  def parse_body
    validate_size!(raw_body.bytesize)
    return parse_text_body if media_type == 'text/plain'
    return parse_json_body if media_type == 'application/json' || media_type.end_with?('+json')

    raise_error('order_update_content_type_invalid', http_status: :unsupported_media_type)
  end

  def parse_text_body
    Ibsoft::ExternalMessaging::FieldPayloadParser.new.call(raw_body)
  end

  def parse_json_body
    decoded = JSON.parse(raw_body)
    raise_error('order_update_json_invalid') unless decoded.is_a?(Hash) && decoded.present?

    normalize_scalar_fields(decoded)
  rescue JSON::ParserError
    raise_error('order_update_json_invalid')
  end

  def normalize_scalar_fields(fields)
    fields.each_with_object({}) do |(name, value), result|
      result[name.to_s] = scalar_value(value).strip
    end
  end

  def scalar_value(value)
    return value.to_s if value.is_a?(String) || value.is_a?(Numeric)

    raise_error('order_update_scalar_values_required')
  end

  def validate_size!(bytes)
    raise_error('order_update_payload_too_large') if bytes > MAX_REQUEST_BYTES
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end

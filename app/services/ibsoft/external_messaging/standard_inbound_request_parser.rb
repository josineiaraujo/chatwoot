class Ibsoft::ExternalMessaging::StandardInboundRequestParser
  MAX_AUTHORIZATION_BYTES = 4.kilobytes
  MAX_PAYLOAD_BYTES = 64.kilobytes
  RECIPIENT_FIELD = 'to'.freeze

  def initialize(method:, authorization:, raw_body:, media_type:, **)
    @method = method.to_s.upcase
    @authorization = authorization.to_s
    @raw_body = raw_body.to_s
    @media_type = media_type.to_s.downcase
  end

  def call
    validate_method!
    validate_media_type!
    token = bearer_token
    payload = validated_payload
    fields = field_parser.call(payload)
    recipient = extract_recipient(fields)

    {
      recipient: recipient,
      fields: fields.except(RECIPIENT_FIELD),
      credentials: { token: token }
    }
  end

  private

  attr_reader :method, :authorization, :raw_body, :media_type

  def validate_method!
    return if method == 'POST'

    raise_error('standard_method_not_allowed', http_status: :method_not_allowed)
  end

  def validate_media_type!
    return if media_type == 'text/plain'

    raise_error('standard_content_type_invalid', http_status: :unsupported_media_type)
  end

  def validated_payload
    raise_error('payload_required') if raw_body.blank?
    raise_error('standard_payload_too_large') if raw_body.bytesize > MAX_PAYLOAD_BYTES

    payload = raw_body.dup.force_encoding(Encoding::UTF_8)
    raise_error('payload_invalid_encoding') unless payload.valid_encoding?

    payload = payload.strip
    raise_error('payload_invalid_format') unless payload.start_with?('[')
    raise_error('payload_invalid_separator') if payload.gsub('||', '').include?('|')

    payload
  end

  def extract_recipient(fields)
    value = fields[RECIPIENT_FIELD].presence
    raise_error('standard_recipient_required') unless value

    normalize_recipient(value)
  end

  def normalize_recipient(value)
    digits = value.to_s.gsub(/\D+/, '')
    raise_error('recipient_invalid') unless digits.match?(/\A[1-9]\d{9,14}\z/)

    digits
  end

  def bearer_token
    raise_error('unauthorized', http_status: :unauthorized) if authorization.bytesize > MAX_AUTHORIZATION_BYTES

    match = authorization.match(/\ABearer[ \t]+([^\s]+)\z/i)
    token = match&.[](1).to_s.strip
    raise_error('unauthorized', http_status: :unauthorized) if token.blank?

    token
  end

  def field_parser
    @field_parser ||= Ibsoft::ExternalMessaging::FieldPayloadParser.new
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end

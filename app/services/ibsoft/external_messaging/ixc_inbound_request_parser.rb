class Ibsoft::ExternalMessaging::IxcInboundRequestParser
  ALLOWED_METHODS = %w[GET POST].freeze
  REQUIRED_FIELDS = %w[user pw dest text].freeze
  RECIPIENT_FIELDS = %w[to recipient destinatario numero_destino telefone_destino].freeze
  JSON_MEDIA_TYPE_SUFFIX = '+json'.freeze
  FORM_MEDIA_TYPE = 'application/x-www-form-urlencoded'.freeze
  MAX_FIELD_BYTES = {
    'user' => 256,
    'pw' => 1024,
    'dest' => 64,
    'text' => 64.kilobytes
  }.freeze

  def initialize(method:, query_parameters:, raw_body:, content_type:, **)
    @method = method.to_s.upcase
    @query_parameters = query_parameters.to_h
    @raw_body = raw_body.to_s
    @content_type = content_type.to_s
  end

  def call
    validate_method!
    validate_content_type!
    envelope = extract_envelope
    destination = normalize_recipient(envelope.fetch('dest'))
    fields = field_parser.call(envelope.fetch('text'))
    validate_embedded_recipients!(fields, destination)

    {
      recipient: destination,
      fields: fields.except(*RECIPIENT_FIELDS),
      credentials: {
        username: envelope.fetch('user'),
        password: envelope.fetch('pw')
      }
    }
  end

  private

  attr_reader :method, :query_parameters, :raw_body, :content_type

  def validate_method!
    return if method.in?(ALLOWED_METHODS)

    raise_error('ixc_method_not_allowed', http_status: :method_not_allowed)
  end

  def validate_content_type!
    return unless method == 'POST' && raw_body.present?
    return if media_type == FORM_MEDIA_TYPE || json_media_type?

    raise_error('ixc_content_type_invalid', http_status: :unsupported_media_type)
  end

  def extract_envelope
    values = scalar_fields(query_parameters)
    values = merge_fields(values, body_fields) if method == 'POST' && raw_body.present?

    REQUIRED_FIELDS.to_h do |field|
      value = values[field].to_s.strip
      raise_error('ixc_field_required', field: field) if value.blank?
      validate_field_size!(field, value)

      [field, validate_encoding(field, value)]
    end
  end

  def body_fields
    parsed = if json_media_type?
               JSON.parse(raw_body)
             else
               Rack::Utils.parse_nested_query(raw_body)
             end
    raise_error('ixc_json_invalid') unless parsed.is_a?(Hash)

    scalar_fields(parsed)
  rescue JSON::ParserError
    raise_error('ixc_json_invalid')
  rescue StandardError => e
    raise unless e.class.name.start_with?('Rack::QueryParser::')

    raise_error('ixc_form_invalid')
  end

  def validate_field_size!(field, value)
    return if value.bytesize <= MAX_FIELD_BYTES.fetch(field)

    code = field == 'text' ? 'ixc_text_too_large' : 'ixc_field_too_large'
    raise_error(code, field: field)
  end

  def scalar_fields(source)
    source.to_h.each_with_object({}) do |(name, value), result|
      raise_error('ixc_scalar_fields_required', field: name) unless scalar_value?(value)

      result[name.to_s] = value.to_s
    end
  end

  def scalar_value?(value)
    value.nil? || value.is_a?(String) || value.is_a?(Numeric) || value.in?([true, false])
  end

  def merge_fields(query, body)
    body.each_with_object(query.dup) do |(name, value), result|
      raise_error('ixc_field_conflict', field: name) if result.key?(name) && result[name] != value

      result[name] = value
    end
  end

  def validate_encoding(field, value)
    utf8_value = value.dup.force_encoding(Encoding::UTF_8)
    raise_error('ixc_text_invalid_encoding') if field == 'text' && !utf8_value.valid_encoding?

    utf8_value
  end

  def normalize_recipient(value)
    digits = value.to_s.gsub(/\D+/, '')
    raise_error('ixc_recipient_invalid') unless digits.match?(/\A[1-9]\d{9,14}\z/)

    digits
  end

  def validate_embedded_recipients!(fields, destination)
    RECIPIENT_FIELDS.each do |field|
      next unless fields.key?(field)

      raise_error('ixc_recipient_conflict') unless normalize_recipient(fields[field]) == destination
    end
  end

  def media_type
    @media_type ||= content_type.split(';', 2).first.to_s.strip.downcase
  end

  def json_media_type?
    media_type == 'application/json' || media_type.end_with?(JSON_MEDIA_TYPE_SUFFIX)
  end

  def field_parser
    @field_parser ||= Ibsoft::ExternalMessaging::FieldPayloadParser.new
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end

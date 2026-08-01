class Ibsoft::ExternalMessaging::InboundRequestParser
  def initialize(method:, parameters:, **)
    @method = method.to_s.upcase
    @parameters = parameters.to_h.deep_stringify_keys
  end

  def call
    raise_error('method_not_allowed', http_status: :method_not_allowed) unless method == 'GET'
    raise_error('payload_required') if parameters['msg'].blank?

    {
      recipient: parameters['to'],
      fields: field_parser.call(extract_payload(parameters['msg'])),
      credentials: { token: parameters['token'] }
    }
  end

  private

  attr_reader :method, :parameters

  def extract_payload(message)
    value = message.to_s.strip
    value = Regexp.last_match(1).strip if value.match?(/\Amsg\s*=\s*(.+)\z/mi)
    return value if value.start_with?('[', '{')

    single_quoted = value.match(/--data-raw(?:=|\s+)'([^']*)'/m)
    return single_quoted[1].strip if single_quoted

    double_quoted = value.match(/--data-raw(?:=|\s+)"((?:\\.|[^"])*)"/m)
    return JSON.parse(%("#{double_quoted[1]}")).strip if double_quoted

    raise_error('message_payload_not_found')
  rescue JSON::ParserError
    raise_error('message_payload_not_found')
  end

  def field_parser
    @field_parser ||= Ibsoft::ExternalMessaging::FieldPayloadParser.new
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end

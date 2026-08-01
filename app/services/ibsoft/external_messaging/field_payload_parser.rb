require 'strscan'

class Ibsoft::ExternalMessaging::FieldPayloadParser
  MAX_PAYLOAD_BYTES = 128.kilobytes
  MAX_FIELDS = 200
  MAX_FIELD_NAME_BYTES = 120
  MAX_FIELD_VALUE_BYTES = 32.kilobytes
  FIELD_NAME_PATTERN = /\A[A-Za-z_][A-Za-z0-9_.-]*\z/

  def call(payload)
    value = payload.to_s.strip
    validate_payload!(value)

    value.start_with?('[') ? parse_pipe_format(value) : parse_legacy_format(value)
  end

  def normalize(fields)
    fields.to_h.each_with_object({}) do |(name, value), result|
      add_field(result, name.to_s, value.to_s)
    end
  end

  private

  def validate_payload!(payload)
    raise_error('payload_required') if payload.blank?
    raise_error('payload_too_large') if payload.bytesize > MAX_PAYLOAD_BYTES
    raise_error('payload_invalid_encoding') unless payload.valid_encoding?
    return if payload.start_with?('[', '{')

    raise_error('payload_invalid_format')
  end

  def parse_pipe_format(payload)
    scanner = StringScanner.new(payload)
    fields = {}
    first = true

    until scanner.eos?
      scanner.skip(/\s*/)
      scan_pipe_separator(scanner) unless first
      scanner.skip(/\s*/)
      match = scanner.scan(/\[([A-Za-z_][A-Za-z0-9_.-]*)\]\s*=\s*([^|\r\n]*)/)
      raise_error('payload_invalid_format') unless match

      add_field(fields, scanner[1], scanner[2])
      first = false
    end

    fields
  end

  def scan_pipe_separator(scanner)
    return if scanner.scan(/\|\|?/)

    raise_error('payload_invalid_separator')
  end

  def parse_legacy_format(payload)
    scanner = StringScanner.new(payload)
    fields = {}
    first = true

    until scanner.eos?
      scanner.skip(/\s*/)
      raise_error('payload_invalid_separator') if !first && !scanner.scan(',')
      scanner.skip(/\s*/)
      match = scanner.scan(/\{([A-Za-z_][A-Za-z0-9_.-]*)\}\s*=\s*\[([^\]\r\n]*)\]/)
      raise_error('payload_invalid_format') unless match

      add_field(fields, scanner[1], scanner[2])
      first = false
    end

    fields
  end

  def add_field(fields, name, value)
    raise_error('payload_too_many_fields') if fields.size >= MAX_FIELDS
    raise_error('field_name_invalid', field: name) unless name.match?(FIELD_NAME_PATTERN)
    raise_error('field_name_too_large', field: name) if name.bytesize > MAX_FIELD_NAME_BYTES
    raise_error('field_value_too_large', field: name) if value.bytesize > MAX_FIELD_VALUE_BYTES
    raise_error('field_duplicated', field: name) if fields.key?(name)

    fields[name] = value.strip
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end

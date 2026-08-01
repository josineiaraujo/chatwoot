class Ibsoft::ExternalMessaging::ValueCoercion
  PARAMETER_NAME_PATTERN = /\A[A-Za-z_][A-Za-z0-9_]*\z/
  ORDER_ID_PATTERN = /\A[A-Za-z0-9_.-]{1,60}\z/

  class << self
    def money_to_minor(value, field:, allow_zero: false)
      normalized = value.to_s.strip.gsub(/[\sR$]/, '')
      whole, cents = monetary_parts(normalized)
      minor = (whole.to_i * 100) + cents.to_i
      return minor if minor.positive? || (allow_zero && minor.zero?)

      raise_error('money_invalid', field: field)
    rescue ArgumentError
      raise_error('money_invalid', field: field)
    end

    def integer(value, field:, minimum:, maximum:)
      string = value.to_s.strip
      raise_error('integer_invalid', field: field) unless string.match?(/\A[0-9]+\z/)

      number = string.to_i
      return number if number.between?(minimum, maximum)

      raise_error('integer_out_of_range', field: field, minimum: minimum, maximum: maximum)
    end

    def order_id(value, field:)
      string = value.to_s.strip
      return string if string.match?(ORDER_ID_PATTERN)

      raise_error('order_id_invalid', field: field)
    end

    def parameter_name(value, field:)
      string = value.to_s
      return string if string.match?(PARAMETER_NAME_PATTERN)

      raise_error('parameter_name_invalid', field: field)
    end

    def https_url(value, field:)
      uri = URI.parse(value.to_s)
      valid = uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.blank?
      return uri.to_s if valid

      raise_error('https_url_invalid', field: field)
    rescue URI::InvalidURIError
      raise_error('https_url_invalid', field: field)
    end

    def boolean(value, field:)
      normalized = value.to_s.strip.downcase
      return true if normalized.in?(%w[1 true yes sim])
      return false if normalized.in?(%w[0 false no nao não])

      raise_error('boolean_invalid', field: field)
    end

    def future_timestamp(value, field:)
      raw = value.to_s.strip
      timestamp = numeric_timestamp(raw) || iso8601_timestamp(raw, field)
      raise_error('expiration_not_future', field: field) unless timestamp.future?

      timestamp.to_i.to_s
    end

    private

    def monetary_parts(normalized)
      brazilian = normalized.match(/\A(0|[1-9][0-9]{0,2}(?:\.[0-9]{3})*),([0-9]{2})\z/)
      return [brazilian[1].delete('.'), brazilian[2]] if brazilian

      decimal = normalized.match(/\A(0|[1-9][0-9]*)(?:\.([0-9]{1,2}))?\z/)
      raise ArgumentError unless decimal

      [decimal[1], decimal[2].to_s.ljust(2, '0')]
    end

    def numeric_timestamp(raw)
      return unless raw.match?(/\A[0-9]{10}(?:[0-9]{3})?\z/)

      value = raw.to_i
      value /= 1000 if raw.length == 13
      Time.zone.at(value)
    end

    def iso8601_timestamp(raw, field)
      raise_error('expiration_timezone_required', field: field) unless raw.match?(/(?:Z|[+-][0-9]{2}:[0-9]{2})\z/)

      Time.iso8601(raw)
    rescue ArgumentError
      raise_error('expiration_invalid', field: field)
    end

    def raise_error(code, **)
      raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
    end
  end
end

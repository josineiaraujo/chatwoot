class Ibsoft::ExternalMessaging::BodyComponentBuilder
  def initialize(fields:)
    @fields = fields
  end

  def call
    values = body_values
    return if values.empty?

    numeric, named = values.partition { |name, _value| name.match?(/\A[1-9][0-9]*\z/) }
    raise_error('body_mixed_variables') if numeric.present? && named.present?

    parameters = numeric.present? ? positional_parameters(numeric) : named_parameters(named)
    { type: 'body', parameters: parameters }
  end

  private

  attr_reader :fields

  def body_values
    fields.each_with_object({}) do |(field, value), result|
      next unless field.start_with?('body.')

      name = field.delete_prefix('body.')
      raise_error('unsupported_field', field: field) if name.blank? || name.include?('.')
      raise_error('field_required', field: field) if value.to_s.strip.blank?

      result[name] = value.to_s
    end
  end

  def positional_parameters(values)
    ordered = values.to_h.transform_keys(&:to_i).sort.to_h
    expected = (1..ordered.size).to_a
    raise_error('body_position_sequence') unless ordered.keys == expected

    ordered.values.map { |value| { type: 'text', text: value } }
  end

  def named_parameters(values)
    values.sort.to_h.map do |name, value|
      parameter_name = Ibsoft::ExternalMessaging::ValueCoercion.parameter_name(
        name,
        field: "body.#{name}"
      )
      { type: 'text', parameter_name: parameter_name, text: value }
    end
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end

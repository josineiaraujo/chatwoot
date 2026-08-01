class Ibsoft::ExternalMessaging::ButtonComponentsBuilder
  TYPES = %w[url copy_code quick_reply].freeze

  def initialize(fields:)
    @fields = fields
  end

  def call
    definitions = button_definitions
    definitions.to_h do |index, definition|
      [index, build_button(index, definition)]
    end
  end

  private

  attr_reader :fields

  def button_definitions
    result = {}
    fields.each do |field, value|
      next unless field.start_with?('button.')

      match = field.match(/\Abutton\.([0-9]+)\.(type|value)\z/)
      raise_error('unsupported_field', field: field) unless match

      index = match[1].to_i
      raise_error('button_index_invalid') unless index.between?(0, 9)
      result[index] ||= {}
      result[index][match[2]] = value.to_s.strip
    end
    result
  end

  def build_button(index, definition)
    type = definition['type'].to_s.downcase
    value = definition['value'].to_s
    raise_error('button_type_invalid', index: index) unless type.in?(TYPES)
    raise_error('field_required', field: "button.#{index}.value") if value.blank?

    {
      type: 'button',
      sub_type: type,
      index: index,
      parameters: [button_parameter(type, value)]
    }
  end

  def button_parameter(type, value)
    case type
    when 'url' then { type: 'text', text: value }
    when 'copy_code' then { type: 'coupon_code', coupon_code: value }
    else { type: 'payload', payload: value }
    end
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end

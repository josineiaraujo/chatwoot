class Ibsoft::ExternalMessaging::OrderItemsBuilder
  ITEM_PATTERN = /\Aorder\.items\.([0-9]+)\.(id|name|amount|quantity)\z/

  def initialize(fields:, reference_id:, total:)
    @fields = fields
    @reference_id = reference_id
    @total = total
  end

  def call
    definitions = item_definitions
    return [default_item] if definitions.empty?

    validate_sequence!(definitions)
    definitions.sort.to_h.map do |index, definition|
      build_item(index, definition)
    end
  end

  private

  attr_reader :fields, :reference_id, :total

  def item_definitions
    fields.each_with_object({}) do |(field, value), result|
      next unless field.start_with?('order.items.')

      match = field.match(ITEM_PATTERN)
      raise_error('unsupported_field', field: field) unless match

      index = match[1].to_i
      result[index] ||= {}
      result[index][match[2]] = value.to_s.strip
    end
  end

  def validate_sequence!(definitions)
    expected = (0...definitions.size).to_a
    raise_error('order_item_sequence') unless definitions.keys.sort == expected
  end

  def build_item(index, definition)
    {
      retailer_id: Ibsoft::ExternalMessaging::ValueCoercion.order_id(
        definition['id'],
        field: "order.items.#{index}.id"
      ),
      name: required(definition, index, 'name'),
      amount: amount(
        Ibsoft::ExternalMessaging::ValueCoercion.money_to_minor(
          required(definition, index, 'amount'),
          field: "order.items.#{index}.amount"
        )
      ),
      quantity: Ibsoft::ExternalMessaging::ValueCoercion.integer(
        required(definition, index, 'quantity'),
        field: "order.items.#{index}.quantity",
        minimum: 1,
        maximum: 999
      )
    }
  end

  def default_item
    name = fields.fetch('order.item_name', 'Fatura').to_s.strip
    raise_error('field_required', field: 'order.item_name') if name.blank?

    {
      retailer_id: reference_id,
      name: name,
      amount: amount(total),
      quantity: 1
    }
  end

  def required(definition, index, name)
    value = definition[name].to_s.strip
    raise_error('field_required', field: "order.items.#{index}.#{name}") if value.blank?

    value
  end

  def amount(value)
    { value: value, offset: 100 }
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end

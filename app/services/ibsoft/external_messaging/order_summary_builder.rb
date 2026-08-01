class Ibsoft::ExternalMessaging::OrderSummaryBuilder
  def initialize(fields:, items:, total:)
    @fields = fields
    @items = items
    @total = total
  end

  def call
    amounts = financial_amounts
    validate_total!(amounts)

    order = base_order(amounts[:subtotal])
    add_optional_amount(order, :tax, amounts[:tax], 'order.tax_description')
    add_optional_amount(order, :shipping, amounts[:shipping], 'order.shipping_description')
    add_discount(order, amounts[:discount])
    expiration_payload = expiration
    order[:expiration] = expiration_payload if expiration_payload
    order
  end

  private

  attr_reader :fields, :items, :total

  def financial_amounts
    {
      subtotal: subtotal,
      tax: optional_money('order.tax'),
      shipping: optional_money('order.shipping'),
      discount: optional_money('order.discount')
    }
  end

  def subtotal
    return money(fields['order.subtotal'], 'order.subtotal') if fields['order.subtotal'].present?

    items.sum { |item| item[:amount][:value] * item[:quantity] }
  end

  def validate_total!(amounts)
    calculated = amounts[:subtotal] + amounts[:tax] + amounts[:shipping] - amounts[:discount]
    return if total == calculated

    raise_error('order_total_mismatch', calculated: calculated)
  end

  def base_order(subtotal)
    {
      status: 'pending',
      items: items,
      subtotal: amount(subtotal)
    }
  end

  def add_optional_amount(order, name, value, description_field)
    return unless fields.key?("order.#{name}")

    order[name] = amount(value)
    description = fields[description_field].to_s.strip
    order[name][:description] = description if description.present?
  end

  def add_discount(order, value)
    add_optional_amount(order, :discount, value, 'order.discount_description')
    return unless order[:discount]

    program = fields['order.discount_program_name'].to_s.strip
    order[:discount][:discount_program_name] = program if program.present?
  end

  def expiration
    raw = fields['order.expiration_at'].to_s.strip
    description = fields['order.expiration_description'].to_s.strip
    if raw.blank?
      raise_error('expiration_without_date') if description.present?

      return
    end

    result = {
      timestamp: Ibsoft::ExternalMessaging::ValueCoercion.future_timestamp(
        raw,
        field: 'order.expiration_at'
      )
    }
    result[:description] = description if description.present?
    result
  end

  def optional_money(field)
    value = fields[field].to_s.strip
    return 0 if value.blank?

    Ibsoft::ExternalMessaging::ValueCoercion.money_to_minor(
      value,
      field: field,
      allow_zero: true
    )
  end

  def money(value, field)
    Ibsoft::ExternalMessaging::ValueCoercion.money_to_minor(value, field: field)
  end

  def amount(value)
    { value: value, offset: 100 }
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end

class Ibsoft::ExternalMessaging::OrderComponentBuilder
  ALLOWED_FIELDS = %w[
    order.reference_id
    order.total
    order.currency
    order.goods_type
    order.button_index
    order.subtotal
    order.tax
    order.tax_description
    order.shipping
    order.shipping_description
    order.discount
    order.discount_description
    order.discount_program_name
    order.item_name
    order.expiration_at
    order.expiration_description
    order.payment.pix.code
    order.payment.pix.merchant_name
    order.payment.pix.key
    order.payment.pix.key_type
    order.payment.boleto.digitable_line
  ].freeze

  def initialize(fields:)
    @fields = fields
  end

  def call
    validate_field_names!
    reference_id = order_id(required('order.reference_id'))
    total = money(required('order.total'), 'order.total')
    items = Ibsoft::ExternalMessaging::OrderItemsBuilder.new(
      fields: fields,
      reference_id: reference_id,
      total: total
    ).call

    build_component(
      reference_id: reference_id,
      total: total,
      items: items
    )
  end

  private

  attr_reader :fields

  def validate_field_names!
    invalid = fields.keys.find do |field|
      field.start_with?('order.') &&
        ALLOWED_FIELDS.exclude?(field) &&
        !field.match?(Ibsoft::ExternalMessaging::OrderItemsBuilder::ITEM_PATTERN)
    end
    raise_error('unsupported_field', field: invalid) if invalid
  end

  def build_component(reference_id:, total:, items:)
    {
      type: 'button',
      sub_type: 'order_details',
      index: button_index,
      parameters: [
        {
          type: 'action',
          action: {
            order_details: order_details(
              reference_id: reference_id,
              total: total,
              items: items
            )
          }
        }
      ]
    }
  end

  def order_details(reference_id:, total:, items:)
    {
      reference_id: reference_id,
      type: goods_type,
      payment_type: 'br',
      payment_settings: Ibsoft::ExternalMessaging::OrderPaymentSettingsBuilder.new(fields: fields).call,
      currency: currency,
      total_amount: amount(total),
      order: Ibsoft::ExternalMessaging::OrderSummaryBuilder.new(
        fields: fields,
        items: items,
        total: total
      ).call
    }
  end

  def button_index
    Ibsoft::ExternalMessaging::ValueCoercion.integer(
      fields.fetch('order.button_index', '0'),
      field: 'order.button_index',
      minimum: 0,
      maximum: 9
    )
  end

  def currency
    value = fields.fetch('order.currency', 'BRL').to_s.strip.upcase
    return value if value.match?(/\A[A-Z]{3}\z/)

    raise_error('currency_invalid')
  end

  def goods_type
    value = fields.fetch('order.goods_type', 'digital-goods').to_s.strip.downcase
    return value if value.in?(%w[digital-goods physical-goods])

    raise_error('goods_type_invalid')
  end

  def required(field)
    value = fields[field].to_s.strip
    raise_error('field_required', field: field) if value.blank?

    value
  end

  def money(value, field)
    Ibsoft::ExternalMessaging::ValueCoercion.money_to_minor(value, field: field)
  end

  def order_id(value)
    Ibsoft::ExternalMessaging::ValueCoercion.order_id(
      value,
      field: 'order.reference_id'
    )
  end

  def amount(value)
    { value: value, offset: 100 }
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end

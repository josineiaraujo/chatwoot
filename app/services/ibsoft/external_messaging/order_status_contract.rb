class Ibsoft::ExternalMessaging::OrderStatusContract
  REFERENCE_FIELDS = %w[fatura_id id_fatura id-fatura reference_id].freeze
  ORDER_STATUS_FIELDS = %w[order_status status_pedido].freeze
  PAYMENT_STATUS_FIELDS = %w[payment_status status_pagamento].freeze
  MESSAGE_FIELDS = %w[message mensagem].freeze
  DESCRIPTION_FIELDS = %w[description descricao].freeze
  KNOWN_FIELDS = (
    REFERENCE_FIELDS + ORDER_STATUS_FIELDS + PAYMENT_STATUS_FIELDS +
    MESSAGE_FIELDS + DESCRIPTION_FIELDS + %w[status payment_timestamp]
  ).freeze
  REFERENCE_PATTERN = /\A[A-Za-z0-9_.-]{1,60}\z/
  MAX_MESSAGE_BYTES = Ibsoft::ExternalMessaging::OrderUpdateMessageCatalog::MAX_MESSAGE_BYTES
  MAX_DESCRIPTION_BYTES = 120

  ORDER_STATUS_ALIASES = {
    'pendente' => 'pending',
    'processando' => 'processing',
    'parcialmente_enviado' => 'partially_shipped',
    'enviado' => 'shipped',
    'concluido' => 'completed',
    'concluído' => 'completed',
    'completo' => 'completed',
    'finalizado' => 'completed',
    'cancelado' => 'canceled',
    'cancelled' => 'canceled'
  }.freeze
  PAYMENT_STATUS_ALIASES = {
    'pendente' => 'pending',
    'pago' => 'captured',
    'capturado' => 'captured',
    'falhou' => 'failed',
    'falha' => 'failed'
  }.freeze
  SHORTCUT_PAYMENT_STATUSES = {
    'pago' => 'captured',
    'paid' => 'captured',
    'captured' => 'captured',
    'pagamento_pendente' => 'pending',
    'payment_pending' => 'pending',
    'pagamento_falhou' => 'failed',
    'payment_failed' => 'failed',
    'failed' => 'failed'
  }.freeze

  def initialize(endpoint:, fields:)
    @endpoint = endpoint
    @fields = normalize_field_names(fields)
  end

  def call
    validate_known_fields!
    reference_id = reference_id!
    order_status, payment_status = statuses
    validate_status_combination!(order_status, payment_status)

    {
      reference_id: reference_id,
      order_status: order_status,
      payment_status: payment_status,
      message_content: message_content(reference_id, order_status, payment_status),
      description: description(order_status),
      payment_timestamp: payment_timestamp(payment_status)
    }
  end

  private

  attr_reader :endpoint, :fields

  def normalize_field_names(source)
    source.to_h.each_with_object({}) do |(name, value), result|
      normalized_name = name.to_s.strip.downcase
      raise_error('field_duplicated', field: normalized_name) if result.key?(normalized_name)

      result[normalized_name] = value.to_s.strip
    end
  end

  def validate_known_fields!
    unknown = fields.keys - KNOWN_FIELDS
    raise_error('unsupported_field', field: unknown.first) if unknown.any?
  end

  def reference_id!
    value = alias_value(REFERENCE_FIELDS, required: true)
    raise_error('order_update_reference_invalid') unless value.match?(REFERENCE_PATTERN)

    value
  end

  def statuses
    shortcut = alias_value(%w[status])
    order_value = alias_value(ORDER_STATUS_FIELDS)
    payment_value = alias_value(PAYMENT_STATUS_FIELDS)
    raise_error('order_update_status_fields_conflict') if shortcut.present? &&
                                                          (order_value.present? || payment_value.present?)

    return shortcut_status(shortcut) if shortcut.present?

    [
      order_value.presence && normalize_order_status(order_value),
      payment_value.presence && normalize_payment_status(payment_value)
    ]
  end

  def validate_status_combination!(order_status, payment_status)
    raise_error('order_update_status_required') if order_status.blank? && payment_status.blank?
    return unless order_status == 'canceled' && payment_status == 'captured'

    raise_error('order_update_invalid_combination')
  end

  def shortcut_status(value)
    normalized = normalize_status_text(value)
    payment_status = SHORTCUT_PAYMENT_STATUSES[normalized]
    return [nil, payment_status] if payment_status

    [normalize_order_status(normalized), nil]
  end

  def normalize_order_status(value)
    normalized = normalize_status_text(value)
    normalized = ORDER_STATUS_ALIASES.fetch(normalized, normalized)
    return normalized if normalized.in?(Ibsoft::ExternalMessaging::Order::ORDER_STATUSES)

    raise_error('order_update_order_status_invalid')
  end

  def normalize_payment_status(value)
    normalized = normalize_status_text(value)
    normalized = PAYMENT_STATUS_ALIASES.fetch(normalized, normalized)
    return normalized if normalized.in?(Ibsoft::ExternalMessaging::Order::PAYMENT_STATUSES)

    raise_error('order_update_payment_status_invalid')
  end

  def normalize_status_text(value)
    value.to_s.strip.downcase.tr('- ', '__')
  end

  def message_content(reference_id, order_status, payment_status)
    value = alias_value(MESSAGE_FIELDS)
    value = default_message(reference_id, order_status, payment_status) if value.blank?
    raise_error('order_update_message_too_large') if value.bytesize > MAX_MESSAGE_BYTES

    value
  end

  def default_message(reference_id, order_status, payment_status)
    key = if payment_status == 'captured' && order_status == 'completed'
            'captured_and_completed'
          elsif payment_status.present?
            "payment_#{payment_status}"
          else
            "order_#{order_status}"
          end
    Ibsoft::ExternalMessaging::OrderUpdateMessageCatalog
      .new(endpoint: endpoint)
      .render(key: key, reference_id: reference_id)
  end

  def description(order_status)
    value = alias_value(DESCRIPTION_FIELDS)
    value = translate("defaults.descriptions.#{order_status}") if value.blank? && order_status.present?
    raise_error('order_update_description_too_large') if value.bytesize > MAX_DESCRIPTION_BYTES

    value.presence
  end

  def payment_timestamp(payment_status)
    value = alias_value(%w[payment_timestamp])
    return if value.blank?

    raise_error('order_update_timestamp_without_payment') if payment_status.blank?
    raise_error('order_update_timestamp_invalid') unless value.match?(/\A[0-9]{1,12}\z/) && value.to_i.positive?

    value.to_i
  end

  def alias_value(aliases, required: false)
    present = aliases.filter_map do |name|
      [name, fields[name]] if fields[name].present?
    end
    raise_error('order_update_alias_conflict', fields: aliases.join(', ')) if present.many?

    value = present.dig(0, 1).to_s
    raise_error('field_required', field: aliases.first) if required && value.blank?
    value
  end

  def translate(key, **)
    locale = endpoint.account.locale.presence || I18n.default_locale
    I18n.t("ibsoft_external_messaging.order_updates.#{key}", locale: locale, **)
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end

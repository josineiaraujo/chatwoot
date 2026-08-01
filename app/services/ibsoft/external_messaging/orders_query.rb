class Ibsoft::ExternalMessaging::OrdersQuery
  FILTER_KEYS = %w[
    recipient
    reference_id
    order_status
    payment_status
    date_from
    date_to
  ].freeze

  def initialize(account:, endpoint:, filters: {}, selected_before: nil)
    @account = account
    @endpoint = endpoint
    @filters = filters.to_h.stringify_keys.slice(*FILTER_KEYS)
    @selected_before = selected_before
  end

  def call
    scope = base_scope
    scope = filter_recipient(scope)
    scope = filter_reference(scope)
    scope = filter_statuses(scope)
    scope = filter_dates(scope)
    scope = scope.where('ibsoft_external_message_orders.created_at <= ?', selected_before) if selected_before
    scope.order(created_at: :desc, id: :desc)
  end

  private

  attr_reader :account, :endpoint, :filters, :selected_before

  def base_scope
    Ibsoft::ExternalMessaging::Order
      .where(account: account)
      .joins(:opening_delivery)
      .where(ibsoft_external_message_deliveries: { endpoint_id: endpoint.id })
  end

  def filter_recipient(scope)
    return scope if filters['recipient'].blank?

    recipient = filters['recipient'].to_s.gsub(/\D/, '')
    raise_error('orders_recipient_invalid') if recipient.length < 3

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(recipient)}%"
    scope.where('ibsoft_external_message_deliveries.recipient LIKE ?', pattern)
  end

  def filter_reference(scope)
    return scope if filters['reference_id'].blank?

    value = filters['reference_id'].to_s.strip
    raise_error('orders_reference_invalid') if value.length > 60

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
    scope.where('ibsoft_external_message_orders.reference_id ILIKE ?', pattern)
  end

  def filter_statuses(scope)
    scope = filter_status(
      scope,
      'order_status',
      Ibsoft::ExternalMessaging::Order::ORDER_STATUSES
    )
    filter_status(
      scope,
      'payment_status',
      Ibsoft::ExternalMessaging::Order::PAYMENT_STATUSES
    )
  end

  def filter_status(scope, field, allowed)
    value = filters[field].to_s
    return scope if value.blank?

    raise_error("orders_#{field}_invalid") unless value.in?(allowed)

    scope.where(field => value)
  end

  def filter_dates(scope)
    from = parsed_date('date_from')
    to = parsed_date('date_to')
    raise_error('orders_date_range_invalid') if from && to && from > to

    scope = scope.where('ibsoft_external_message_orders.created_at >= ?', from.beginning_of_day) if from
    scope = scope.where('ibsoft_external_message_orders.created_at <= ?', to.end_of_day) if to
    scope
  end

  def parsed_date(field)
    value = filters[field].to_s
    return if value.blank?

    Date.iso8601(value)
  rescue Date::Error
    raise_error('orders_date_invalid')
  end

  def raise_error(code)
    raise Ibsoft::ExternalMessaging::InvalidRequest, code
  end
end

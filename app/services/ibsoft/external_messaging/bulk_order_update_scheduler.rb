class Ibsoft::ExternalMessaging::BulkOrderUpdateScheduler
  Result = Struct.new(:matched_count, :selection, :filters, :attributes, :selected_before, keyword_init: true)
  MODES = %w[ids filter].freeze
  MAX_EXPLICIT_IDS = 100

  def initialize(account:, endpoint:, user:, params:)
    @account = account
    @endpoint = endpoint
    @user = user
    @params = params.to_h.with_indifferent_access
  end

  def call
    selected_before = Time.current
    selection = normalized_selection
    attributes = normalized_attributes
    filters = normalized_filters
    scope = eligible_scope(filters, selection, selected_before)
    count = scope.count
    raise_error('orders_selection_empty') if count.zero?

    enqueue_job(selection, filters, attributes, selected_before)

    build_result(
      count: count,
      selection: selection,
      filters: filters,
      attributes: attributes,
      selected_before: selected_before
    )
  end

  private

  def enqueue_job(selection, filters, attributes, selected_before)
    enqueue(
      account_id: account.id,
      endpoint_id: endpoint.id,
      requested_by_id: user.id,
      selection: selection,
      filters: filters,
      attributes: attributes,
      selected_before: selected_before.iso8601(6)
    )
  end

  def build_result(count:, selection:, filters:, attributes:, selected_before:)
    Result.new(
      matched_count: count,
      selection: selection,
      filters: filters,
      attributes: attributes,
      selected_before: selected_before
    )
  end

  attr_reader :account, :endpoint, :user, :params

  def normalized_selection
    selection = params.fetch(:selection, {}).to_h.with_indifferent_access
    mode = selection[:mode].to_s
    raise_error('orders_selection_invalid') unless mode.in?(MODES)

    return { mode: 'filter' } if mode == 'filter'

    ids = Array(selection[:ids]).filter_map do |id|
      Integer(id, exception: false) if id.to_s.match?(/\A[0-9]+\z/)
    end.uniq
    raise_error('orders_selection_empty') if ids.empty?
    raise_error('orders_selection_too_large') if ids.length > MAX_EXPLICIT_IDS

    { mode: 'ids', ids: ids }
  end

  def normalized_attributes
    values = params.fetch(:update, {}).to_h.with_indifferent_access
    order_status = values[:order_status].to_s.presence
    payment_status = values[:payment_status].to_s.presence
    raise_error('order_update_status_required') if order_status.blank? && payment_status.blank?
    validate_order_status(order_status)
    validate_payment_status(payment_status)
    validate_status_combination(order_status, payment_status)

    {
      order_status: order_status,
      payment_status: payment_status
    }.compact
  end

  def validate_order_status(value)
    return if value.blank? || value.in?(Ibsoft::ExternalMessaging::Order::ORDER_STATUSES)

    raise_error('order_update_order_status_invalid')
  end

  def validate_payment_status(value)
    return if value.blank? || value.in?(Ibsoft::ExternalMessaging::Order::PAYMENT_STATUSES)

    raise_error('order_update_payment_status_invalid')
  end

  def validate_status_combination(order_status, payment_status)
    return unless order_status == 'canceled' && payment_status == 'captured'

    raise_error('order_update_invalid_combination')
  end

  def normalized_filters
    params.fetch(:filters, {}).to_h.stringify_keys.slice(
      *Ibsoft::ExternalMessaging::OrdersQuery::FILTER_KEYS
    )
  end

  def eligible_scope(filters, selection, selected_before)
    scope = Ibsoft::ExternalMessaging::OrdersQuery.new(
      account: account,
      endpoint: endpoint,
      filters: filters,
      selected_before: selected_before
    ).call.manually_updateable
    return scope.where(id: selection[:ids]) if selection[:mode] == 'ids'

    scope
  end

  def enqueue(arguments)
    Ibsoft::ExternalMessaging::BulkOrderUpdateJob.perform_later(arguments)
  end

  def raise_error(code)
    raise Ibsoft::ExternalMessaging::InvalidRequest, code
  end
end

class Ibsoft::ExternalMessaging::OrderUpdateCreator
  Result = Struct.new(:order, :update, :created, :unchanged, keyword_init: true)

  def initialize(endpoint:, command:, recipient: nil, requested_by: nil, source: 'external_api')
    @endpoint = endpoint
    @command = command.to_h.symbolize_keys
    @recipient = recipient.to_s.presence
    @requested_by = requested_by
    @source = source
  end

  def call
    order = find_order!
    raise_error('order_update_not_ready', http_status: :conflict) unless order.ready_for_updates?

    order.with_lock { create_locked(order) }
  end

  private

  attr_reader :endpoint, :command, :recipient, :requested_by, :source

  def create_locked(order)
    raise_error('order_update_blocked', http_status: :conflict) if uncertain_update?(order)

    active_updates = active_updates(order)
    projected = projected_statuses(order, active_updates)
    return duplicate_or_unchanged_result(order, active_updates) if requested_statuses_match?(projected)

    validate_cancellation!(projected[:payment_status])
    create_result(order)
  end

  def active_updates(order)
    order.updates.where(status: Ibsoft::ExternalMessaging::OrderUpdate::ACTIVE_STATUSES).to_a
  end

  def create_result(order)
    update = order.updates.create!(
      endpoint: endpoint,
      account: endpoint.account,
      inbox: endpoint.inbox,
      order_status: command[:order_status],
      payment_status: command[:payment_status],
      message_content: command[:message_content],
      description: command[:description],
      payment_timestamp: command[:payment_timestamp],
      requested_by: requested_by,
      source: source,
      status: 'queued',
      received_at: Time.current
    )
    Result.new(order: order, update: update, created: true, unchanged: false)
  end

  def find_order!
    scope = Ibsoft::ExternalMessaging::Order.includes(:opening_delivery).where(
      account: endpoint.account,
      inbox: endpoint.inbox,
      reference_id: command[:reference_id]
    )
    scope = scope.where(ibsoft_external_message_deliveries: { recipient: recipient }) if recipient.present?
    scope.first!
  rescue ActiveRecord::RecordNotFound
    raise_error('order_update_not_found', http_status: :not_found)
  end

  def uncertain_update?(order)
    order.updates.exists?(status: 'uncertain')
  end

  def projected_statuses(order, active_updates)
    active_updates.each_with_object(
      order_status: order.order_status,
      payment_status: order.payment_status
    ) do |update, projected|
      projected[:order_status] = update.order_status if update.order_status.present?
      projected[:payment_status] = update.payment_status if update.payment_status.present?
    end
  end

  def requested_statuses_match?(projected)
    (command[:order_status].blank? || command[:order_status] == projected[:order_status]) &&
      (command[:payment_status].blank? || command[:payment_status] == projected[:payment_status])
  end

  def duplicate_or_unchanged_result(order, active_updates)
    return Result.new(order: order, created: false, unchanged: true) if active_updates.empty?

    duplicate = active_updates.reverse.find do |update|
      (command[:order_status].blank? || command[:order_status] == update.order_status) &&
        (command[:payment_status].blank? || command[:payment_status] == update.payment_status)
    end
    Result.new(
      order: order,
      update: duplicate || active_updates.last,
      created: false,
      unchanged: false
    )
  end

  def validate_cancellation!(projected_payment_status)
    return unless command[:order_status] == 'canceled'
    return unless projected_payment_status.in?(%w[pending captured])

    raise_error('order_update_cancellation_conflict', http_status: :conflict)
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end

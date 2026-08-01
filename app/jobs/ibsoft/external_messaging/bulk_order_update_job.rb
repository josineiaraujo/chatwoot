class Ibsoft::ExternalMessaging::BulkOrderUpdateJob < ApplicationJob
  queue_as :medium

  BATCH_SIZE = 100

  def perform(arguments)
    arguments = arguments.to_h.with_indifferent_access
    endpoint = endpoint_for(arguments[:account_id], arguments[:endpoint_id])
    requested_by = requested_by_for(arguments[:account_id], arguments[:requested_by_id])
    return if endpoint.blank? || requested_by.blank?

    orders = batch_scope(
      endpoint: endpoint,
      selection: arguments[:selection],
      filters: arguments[:filters],
      selected_before: arguments[:selected_before],
      cursor: arguments[:cursor]
    ).to_a
    orders.each { |order| process_order(endpoint, requested_by, order, arguments[:attributes]) }
    enqueue_next_batch(orders: orders, arguments: arguments)
  end

  private

  def endpoint_for(account_id, endpoint_id)
    Ibsoft::ExternalMessaging::Endpoint.find_by(id: endpoint_id, account_id: account_id)
  end

  def requested_by_for(account_id, user_id)
    User.joins(:account_users).find_by(id: user_id, account_users: { account_id: account_id })
  end

  def batch_scope(endpoint:, selection:, filters:, selected_before:, cursor:)
    scope = Ibsoft::ExternalMessaging::OrdersQuery.new(
      account: endpoint.account,
      endpoint: endpoint,
      filters: filters,
      selected_before: Time.iso8601(selected_before)
    ).call.manually_updateable
    scope = scope.where(id: selection['ids'] || selection[:ids]) if (selection['mode'] || selection[:mode]) == 'ids'
    scope = scope.where('ibsoft_external_message_orders.id > ?', cursor) if cursor
    scope.reorder(id: :asc).limit(BATCH_SIZE)
  end

  def process_order(endpoint, requested_by, order, attributes)
    command = Ibsoft::ExternalMessaging::OrderStatusContract.new(
      endpoint: endpoint,
      fields: attributes.to_h.merge(reference_id: order.reference_id)
    ).call
    result = Ibsoft::ExternalMessaging::OrderUpdateCreator.new(
      endpoint: endpoint,
      command: command,
      requested_by: requested_by,
      source: 'manual'
    ).call
    enqueue_update(result.update) if result.created
  rescue Ibsoft::ExternalMessaging::InvalidRequest => e
    Rails.logger.warn(
      "[Ibsoft::ExternalMessaging] manual order update skipped order=#{order.id} code=#{e.code}"
    )
  end

  def enqueue_update(update)
    Ibsoft::ExternalMessaging::SendOrderUpdateJob.perform_later(update.id)
    update.update_column(:enqueued_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
  rescue StandardError => e
    Rails.logger.error(
      "[Ibsoft::ExternalMessaging] manual update enqueue failed order_update=#{update.id} error=#{e.class}"
    )
  end

  def enqueue_next_batch(orders:, arguments:)
    return if orders.length < BATCH_SIZE

    self.class.perform_later(arguments.merge(cursor: orders.last.id))
  end
end

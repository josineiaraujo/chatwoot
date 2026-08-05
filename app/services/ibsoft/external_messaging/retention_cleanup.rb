class Ibsoft::ExternalMessaging::RetentionCleanup
  BATCH_SIZE = 500

  Result = Struct.new(:orders, :order_updates, :deliveries, keyword_init: true)

  def initialize(endpoint:, now: Time.current)
    @endpoint = endpoint
    @cutoff = endpoint.retention_days.days.ago(now)
  end

  def call
    result = Result.new(orders: 0, order_updates: 0, deliveries: 0)
    purge_expired_orders(result)
    purge_expired_updates(result)
    purge_expired_deliveries(result)
    result
  end

  private

  attr_reader :endpoint, :cutoff

  def purge_expired_orders(result)
    expired_order_scope.in_batches(of: BATCH_SIZE) do |relation|
      order_ids = relation.pluck(:id)
      next if order_ids.empty?

      ApplicationRecord.transaction do
        result.order_updates += Ibsoft::ExternalMessaging::OrderUpdate.where(order_id: order_ids).delete_all
        result.orders += Ibsoft::ExternalMessaging::Order.where(id: order_ids).delete_all
      end
    end
  end

  def expired_order_scope
    Ibsoft::ExternalMessaging::Order
      .where(endpoint: endpoint)
      .where('updated_at < ?', cutoff)
  end

  def purge_expired_updates(result)
    scope = Ibsoft::ExternalMessaging::OrderUpdate
            .where(endpoint: endpoint)
            .where('created_at < ?', cutoff)
    scope.in_batches(of: BATCH_SIZE) do |relation|
      result.order_updates += relation.delete_all
    end
  end

  def purge_expired_deliveries(result)
    referenced_ids = Ibsoft::ExternalMessaging::Order.select(:opening_delivery_id)
    scope = expired_deliveries.where.not(id: referenced_ids)
    scope.in_batches(of: BATCH_SIZE) do |relation|
      result.deliveries += relation.delete_all
    end
  end

  def expired_deliveries
    Ibsoft::ExternalMessaging::Delivery
      .where(endpoint: endpoint)
      .where('created_at < ?', cutoff)
  end
end

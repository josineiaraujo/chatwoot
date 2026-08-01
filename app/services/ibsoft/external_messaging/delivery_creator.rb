class Ibsoft::ExternalMessaging::DeliveryCreator
  Result = Struct.new(:delivery, :created, keyword_init: true)

  class IdempotencyConflict < StandardError; end

  def initialize(endpoint:, attributes:)
    @endpoint = endpoint
    @attributes = attributes
  end

  def call
    existing = endpoint.deliveries.find_by(idempotency_key: attributes[:idempotency_key])
    return existing_result(existing) if existing
    return existing_order_result if existing_order

    delivery = Ibsoft::ExternalMessaging::Delivery.transaction do
      created_delivery = endpoint.deliveries.create!(
        attributes.merge(
          account: endpoint.account,
          inbox: endpoint.inbox,
          status: 'queued',
          received_at: Time.current
        )
      )
      create_order!(created_delivery) if created_delivery.order_template?
      created_delivery
    end
    Result.new(delivery: delivery, created: true)
  rescue ActiveRecord::RecordNotUnique
    duplicate_after_race
  end

  private

  attr_reader :endpoint, :attributes

  def existing_result(delivery)
    raise IdempotencyConflict unless delivery.request_fingerprint == attributes[:request_fingerprint]

    Result.new(delivery: delivery, created: false)
  end

  def existing_order
    return unless attributes[:template_type] == 'order'

    @existing_order ||= Ibsoft::ExternalMessaging::Order.find_by(
      account: endpoint.account,
      inbox: endpoint.inbox,
      reference_id: attributes[:order_reference_id]
    )
  end

  def existing_order_result
    Result.new(delivery: existing_order.opening_delivery, created: false)
  end

  def create_order!(delivery)
    Ibsoft::ExternalMessaging::Order.create!(
      account: endpoint.account,
      inbox: endpoint.inbox,
      opening_delivery: delivery,
      reference_id: delivery.order_reference_id
    )
  end

  def duplicate_after_race
    existing_delivery = endpoint.deliveries.find_by(idempotency_key: attributes[:idempotency_key])
    return existing_result(existing_delivery) if existing_delivery

    @existing_order = nil
    return existing_order_result if existing_order

    raise
  end
end

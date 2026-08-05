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

    return create_standard_delivery unless order_template?

    order = existing_order
    return create_order_resend(order) if order

    create_opening_order_delivery
  rescue ActiveRecord::RecordNotUnique => e
    duplicate_after_race(e)
  end

  private

  attr_reader :endpoint, :attributes

  def existing_result(delivery)
    raise IdempotencyConflict unless delivery.request_fingerprint == attributes[:request_fingerprint]

    Result.new(delivery: delivery, created: false)
  end

  def order_template?
    attributes[:template_type] == 'order'
  end

  def existing_order
    Ibsoft::ExternalMessaging::Order.find_by(
      endpoint: endpoint,
      reference_id: attributes[:order_reference_id]
    )
  end

  def create_standard_delivery
    delivery = endpoint.deliveries.create!(delivery_attributes)
    Result.new(delivery: delivery, created: true)
  end

  def create_opening_order_delivery
    delivery = Ibsoft::ExternalMessaging::Delivery.transaction do
      created_delivery = endpoint.deliveries.create!(delivery_attributes)
      order = Ibsoft::ExternalMessaging::Order.create!(
        endpoint: endpoint,
        account: endpoint.account,
        inbox: endpoint.inbox,
        opening_delivery: created_delivery,
        reference_id: created_delivery.order_reference_id
      )
      created_delivery.update!(external_order: order)
      created_delivery
    end
    Result.new(delivery: delivery, created: true)
  end

  def create_order_resend(order)
    order.with_lock do
      validate_order_resend!(order)
      delivery = endpoint.deliveries.create!(
        delivery_attributes.merge(external_order: order)
      )
      order.update!(updated_at: Time.current)
      Result.new(delivery: delivery, created: true)
    end
  end

  def validate_order_resend!(order)
    raise_invalid_request('order_resend_disabled') unless endpoint.allow_order_resends?
    raise_invalid_request('order_recipient_mismatch') unless order.recipient == attributes[:recipient]
    raise_invalid_request('order_resend_finalized') if order.finalized_for_resend?
  end

  def delivery_attributes
    attributes.merge(
      account: endpoint.account,
      inbox: endpoint.inbox,
      status: 'queued',
      received_at: Time.current
    )
  end

  def duplicate_after_race(error)
    existing_delivery = endpoint.deliveries.find_by(idempotency_key: attributes[:idempotency_key])
    return existing_result(existing_delivery) if existing_delivery

    order = existing_order
    return create_order_resend(order) if order

    raise error
  end

  def raise_invalid_request(code)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, http_status: :conflict)
  end
end

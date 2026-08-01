class Ibsoft::ExternalMessaging::SendDeliveryJob < ApplicationJob
  queue_as :medium

  def perform(delivery_id)
    delivery = Ibsoft::ExternalMessaging::Delivery.find_by(id: delivery_id)
    return if delivery.blank?

    Ibsoft::ExternalMessaging::DeliverySender.new(delivery: delivery).call
  end
end

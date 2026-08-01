class Ibsoft::ExternalMessaging::SendOrderUpdateJob < ApplicationJob
  queue_as :medium

  def perform(order_update_id)
    update = Ibsoft::ExternalMessaging::OrderUpdate.find_by(id: order_update_id)
    return if update.blank?

    Ibsoft::ExternalMessaging::OrderUpdateSender.new(update: update).call
  end
end

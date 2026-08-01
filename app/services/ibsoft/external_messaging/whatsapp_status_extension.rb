module Ibsoft::ExternalMessaging::WhatsappStatusExtension
  private

  def process_statuses
    status = @processed_params[:statuses].first
    return super if status.blank?

    delivery = Ibsoft::ExternalMessaging::Delivery.find_by(
      inbox_id: inbox.id,
      meta_message_id: status[:id]
    )
    return Ibsoft::ExternalMessaging::StatusUpdater.new(delivery: delivery, status: status).call if delivery

    order_update = Ibsoft::ExternalMessaging::OrderUpdate.find_by(
      inbox_id: inbox.id,
      meta_message_id: status[:id]
    )
    return super unless order_update

    Ibsoft::ExternalMessaging::StatusUpdater.new(trackable: order_update, status: status).call
  rescue StandardError => e
    Rails.logger.error(
      "[Ibsoft::ExternalMessaging] status update failed error=#{e.class} message=#{e.message}"
    )
    super
  end
end

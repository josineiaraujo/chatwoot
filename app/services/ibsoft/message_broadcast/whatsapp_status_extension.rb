module Ibsoft::MessageBroadcast::WhatsappStatusExtension
  private

  def process_statuses
    status = @processed_params[:statuses].first
    return super if status.blank?

    recipient = Ibsoft::MessageBroadcast::Recipient
                .joins(:broadcast)
                .find_by(
                  ibsoft_message_broadcasts: { inbox_id: inbox.id },
                  meta_message_id: status[:id]
                )
    return super unless recipient

    Ibsoft::MessageBroadcast::StatusUpdater.new(recipient: recipient, status: status).call
    super if recipient.message_id.present?
  rescue StandardError => e
    Rails.logger.error(
      "[Ibsoft::MessageBroadcast] status update failed error=#{e.class} message=#{e.message}"
    )
    super
  end
end

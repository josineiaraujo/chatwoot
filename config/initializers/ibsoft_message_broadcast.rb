Rails.application.config.to_prepare do
  extension = Ibsoft::MessageBroadcast::WhatsappStatusExtension
  service = Whatsapp::IncomingMessageBaseService
  service.prepend(extension) unless extension > service
end

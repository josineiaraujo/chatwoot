Rails.application.config.to_prepare do
  extension = Ibsoft::ExternalMessaging::WhatsappStatusExtension
  service = Whatsapp::IncomingMessageBaseService
  service.prepend(extension) unless extension > service
end

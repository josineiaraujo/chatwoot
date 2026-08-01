# frozen_string_literal: true

Rails.application.config.to_prepare do
  extension = Ibsoft::InstagramInbound::InstagramEventsJobExtension
  Webhooks::InstagramEventsJob.prepend(extension) unless extension > Webhooks::InstagramEventsJob
end

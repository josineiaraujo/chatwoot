# frozen_string_literal: true

Rails.application.config.to_prepare do
  extension = Ibsoft::Conversation::BulkActionsJobExtension
  BulkActionsJob.prepend(extension) unless extension > BulkActionsJob
end

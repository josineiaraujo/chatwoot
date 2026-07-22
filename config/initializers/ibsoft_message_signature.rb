# frozen_string_literal: true

Rails.application.config.to_prepare do
  builder = Messages::MessageBuilder
  builder_extension = Ibsoft::MessageSignature::MessageBuilderExtension
  api_context_extension = Ibsoft::MessageSignature::ApiRequestContext

  builder.prepend(builder_extension) unless builder.ancestors.include?(builder_extension)
  Api::BaseController.include(api_context_extension) unless api_context_extension >= Api::BaseController
end

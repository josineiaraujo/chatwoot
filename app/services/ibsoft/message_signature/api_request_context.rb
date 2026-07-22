# frozen_string_literal: true

module Ibsoft::MessageSignature::ApiRequestContext
  extend ActiveSupport::Concern

  included do
    around_action :with_ibsoft_message_signature_request_context
  end

  private

  def with_ibsoft_message_signature_request_context(&)
    Ibsoft::MessageSignature::RequestContext.set(
      external_api_request: authenticate_by_access_token?,
      &
    )
  end
end

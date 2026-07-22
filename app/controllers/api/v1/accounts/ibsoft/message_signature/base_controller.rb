# frozen_string_literal: true

class Api::V1::Accounts::Ibsoft::MessageSignature::BaseController < Api::V1::Accounts::BaseController
  before_action :check_ibsoft_message_signature_authorization!

  private

  def check_ibsoft_message_signature_authorization!
    return if Ibsoft::MessageSignature::Permission.can_manage?(Current.account_user)

    raise Pundit::NotAuthorizedError
  end
end

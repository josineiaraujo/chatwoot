class Api::V1::Accounts::Ibsoft::ChathubSettings::BaseController < Api::V1::Accounts::BaseController
  before_action :check_ibsoft_chathub_settings_authorization!

  private

  def check_ibsoft_chathub_settings_authorization!
    return if Ibsoft::ChathubSettings::Permission.can_manage?(Current.account_user)

    raise Pundit::NotAuthorizedError
  end
end

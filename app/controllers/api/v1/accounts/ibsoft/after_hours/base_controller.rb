class Api::V1::Accounts::Ibsoft::AfterHours::BaseController < Api::V1::Accounts::BaseController
  before_action :check_ibsoft_settings_authorization!

  private

  def check_ibsoft_settings_authorization!
    return if Ibsoft::ChathubSettings::Permission.can_manage?(Current.account_user)

    raise Pundit::NotAuthorizedError
  end

  def policy_scope
    Ibsoft::AfterHours::Policy.where(account: Current.account)
  end
end

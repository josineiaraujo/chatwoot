class Api::V1::Accounts::Ibsoft::BusinessCalendar::BaseController < Api::V1::Accounts::BaseController
  before_action :check_ibsoft_settings_authorization!

  private

  def check_ibsoft_settings_authorization!
    return if Ibsoft::ChathubSettings::Permission.can_manage?(Current.account_user)

    raise Pundit::NotAuthorizedError
  end

  def calendar_scope
    Ibsoft::BusinessCalendar::Calendar.where(account: Current.account)
  end

  def set_calendar
    @calendar = calendar_scope.find(params[:calendar_id] || params[:id])
  end
end

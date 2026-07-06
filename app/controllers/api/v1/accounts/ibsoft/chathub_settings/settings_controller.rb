class Api::V1::Accounts::Ibsoft::ChathubSettings::SettingsController <
  Api::V1::Accounts::Ibsoft::ChathubSettings::BaseController
  def show
    render json: setting.payload
  end

  def update
    setting.update!(config: params[:config] || {})

    render json: setting.payload
  end

  private

  def setting
    @setting ||= Ibsoft::ChathubSettings::SettingsResolver.setting_for(Current.account)
  end
end

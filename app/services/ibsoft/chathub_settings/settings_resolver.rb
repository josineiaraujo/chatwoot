class Ibsoft::ChathubSettings::SettingsResolver
  def self.config_for(account)
    setting = Ibsoft::ChathubSettings::AccountSetting.find_or_initialize_by(account: account)
    setting.effective_config
  end

  def self.setting_for(account)
    Ibsoft::ChathubSettings::AccountSetting.find_or_create_by!(account: account)
  end
end

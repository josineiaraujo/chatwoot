class Ibsoft::ChathubSettings::Permission
  PERMISSION = 'ibsoft_chathub_settings_manage'.freeze

  def self.permissions_for(_account_user)
    []
  end

  def self.can_manage?(account_user)
    account_user&.administrator? ||
      Ibsoft::AccessControl::PermissionResolver.permission?(account_user, PERMISSION)
  end
end

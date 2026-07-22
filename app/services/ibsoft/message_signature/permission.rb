# frozen_string_literal: true

class Ibsoft::MessageSignature::Permission
  PERMISSION = 'ibsoft_chathub_settings_manage'

  def self.can_manage?(account_user)
    account_user&.administrator? ||
      Ibsoft::AccessControl::PermissionResolver.permission?(account_user, PERMISSION)
  end
end

# frozen_string_literal: true

class Ibsoft::MessageBroadcast::Permission
  PERMISSION = 'ibsoft_message_broadcast_manage'

  def self.can_manage?(account_user)
    Ibsoft::AccessControl::PermissionResolver.permission?(account_user, PERMISSION)
  end
end

class Ibsoft::ConversationDistribution::SupervisorPermission
  PERMISSION = 'ibsoft_conversation_distribution_supervise'.freeze

  def self.permissions_for(_account_user)
    []
  end

  def self.can_read?(account_user)
    account_user&.administrator? ||
      Ibsoft::AccessControl::PermissionResolver.permission?(account_user, PERMISSION)
  end
end

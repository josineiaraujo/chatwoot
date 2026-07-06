class Ibsoft::ChathubAnalytics::Permission
  def self.can_read_agent?(account_user)
    account_user.present?
  end

  def self.can_read_supervisor?(account_user)
    Ibsoft::ConversationDistribution::SupervisorPermission.can_read?(account_user)
  end
end

module Ibsoft::AccessControl::UnreadCountsCounter
  private

  def custom_role_agent?
    super || (account_user&.agent? && Ibsoft::AccessControl::PermissionResolver.role_assigned?(account_user))
  end

  def permissions
    (super + Ibsoft::AccessControl::PermissionResolver.permissions_for(account_user)).uniq
  end
end

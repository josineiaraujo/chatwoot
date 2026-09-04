module Ibsoft::AccessControl::AccountUserPermissions
  def permissions
    (super + Ibsoft::PermissionRegistry.permissions_for(self)).uniq
  end
end

module Ibsoft::AccessControl::ContactPolicy
  def export?
    Ibsoft::AccessControl::PermissionResolver.permission?(account_user, 'contact_manage') || super
  end

  def import?
    Ibsoft::AccessControl::PermissionResolver.permission?(account_user, 'contact_manage') || super
  end
end

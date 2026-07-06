module Ibsoft::AccessControl::ReportPolicy
  def view?
    Ibsoft::AccessControl::PermissionResolver.permission?(account_user, 'report_manage') || super
  end
end

class Ibsoft::AccessControl::PermissionResolver
  ROLE_MARKER_PERMISSION = 'ibsoft_access_role'.freeze
  DASHBOARD_CUSTOM_ROLE_MARKER = 'custom_role'.freeze

  def self.permissions_for(account_user)
    role = role_for(account_user)
    return [] if role.blank?

    (role.permissions + [ROLE_MARKER_PERMISSION, DASHBOARD_CUSTOM_ROLE_MARKER]).uniq
  end

  def self.role_for(account_user)
    assignment_for(account_user)&.role
  end

  def self.assignment_for(account_user)
    return if account_user.blank?

    Ibsoft::AccessControl::RoleAssignment
      .includes(:role)
      .find_by(account_id: account_user.account_id, user_id: account_user.user_id)
  end

  def self.role_assigned?(account_user)
    role_for(account_user).present?
  end

  def self.permission?(account_user, permission)
    return true if account_user&.administrator?

    permissions_for(account_user).include?(permission)
  end
end

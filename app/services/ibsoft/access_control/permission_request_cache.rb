class Ibsoft::AccessControl::PermissionRequestCache < ActiveSupport::CurrentAttributes
  attribute :assignments_by_user_id

  def self.assignment_for(account_user)
    return if account_user.blank?

    assignments_for(account_user.user_id)[account_user.account_id]
  end

  def self.invalidate(user_id)
    assignments_by_user_id&.delete(user_id)
  end

  def self.assignments_for(user_id)
    self.assignments_by_user_id ||= {}
    assignments_by_user_id[user_id] ||=
      Ibsoft::AccessControl::RoleAssignment
      .includes(:role)
      .where(user_id: user_id)
      .index_by(&:account_id)
  end

  private_class_method :assignments_for
end

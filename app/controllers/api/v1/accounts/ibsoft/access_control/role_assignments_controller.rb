class Api::V1::Accounts::Ibsoft::AccessControl::RoleAssignmentsController <
  Api::V1::Accounts::Ibsoft::AccessControl::BaseController
  def index
    render json: {
      assignments: assignments.map(&:payload),
      roles: roles.map(&:payload),
      users: users_payload,
      available_users: available_users_payload
    }
  end

  def create
    assignment = Ibsoft::AccessControl::RoleAssignment.find_or_initialize_by(
      account: Current.account,
      user: target_user
    )
    assignment.role = role
    assignment.created_by ||= Current.user
    assignment.save!

    render json: assignment.payload
  end

  def destroy
    assignment = Ibsoft::AccessControl::RoleAssignment.find_by!(
      account: Current.account,
      id: params[:id]
    )
    assignment.destroy!

    head :no_content
  end

  private

  def assignments
    @assignments ||= Ibsoft::AccessControl::RoleAssignment
                     .includes(:role, :user, :created_by)
                     .where(account: Current.account)
                     .order(created_at: :desc)
  end

  def roles
    @roles ||= Ibsoft::AccessControl::Role
               .includes(:role_assignments)
               .where(account: Current.account)
               .order(:name)
  end

  def role
    @role ||= Ibsoft::AccessControl::Role.find_by!(
      account: Current.account,
      id: params[:role_id]
    )
  end

  def target_user
    @target_user ||= Current.account.users.find(params[:user_id])
  end

  def available_users_payload
    assigned_user_ids = assignments.map(&:user_id)
    Current.account.users
           .where.not(id: assigned_user_ids)
           .order(:name)
           .map { |user| user_payload(user) }
  end

  def users_payload
    Current.account.users
           .order(:name)
           .map { |user| user_payload(user) }
  end

  def user_payload(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      avatar_url: user.avatar_url
    }
  end
end

class Api::V1::Accounts::Ibsoft::AgentProvisioning::AgentsController <
  Api::V1::Accounts::Ibsoft::AgentProvisioning::BaseController
  def index
    render json: {
      agents: agents.map { |agent| agent_payload(agent) },
      profiles: profiles.map(&:payload)
    }
  end

  def create
    result = Ibsoft::AgentProvisioning::CreateAgent.new(
      account: Current.account,
      inviter: Current.user,
      params: agent_params
    ).perform

    render json: {
      agent: agent_payload(result.user),
      temporary_password: result.temporary_password
    }
  rescue Ibsoft::AgentProvisioning::CreateAgent::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  def update
    user_attributes = agent_user_update_params

    agent.skip_reconfirmation! if user_attributes[:email].present?
    agent.update!(user_attributes) if user_attributes.present?
    agent.current_account_user.update!(account_user_update_params)
    update_avatar!(agent)

    render json: {
      agent: agent_payload(agent.reload)
    }
  end

  def reset_temporary_password
    result = Ibsoft::AgentProvisioning::ResetTemporaryPassword.new(
      account: Current.account,
      user: agent
    ).perform

    render json: {
      agent: agent_payload(result.user),
      temporary_password: result.temporary_password
    }
  rescue Ibsoft::AgentProvisioning::ResetTemporaryPassword::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  private

  def agent_params
    params.require(:agent).permit(:name, :email, :role, :profile_id, :avatar, :auto_offline)
  end

  def agent_update_params
    params.require(:agent).permit(:name, :email, :role, :availability, :auto_offline, :avatar, :remove_avatar)
  end

  def agent
    @agent ||= agents.find(params[:id])
  end

  def agents
    @agents ||= Current.account.users
                       .order_by_full_name
                       .includes(:account_users, { avatar_attachment: [:blob] })
  end

  def profiles
    @profiles ||= Ibsoft::AccessControl::Role
                  .where(account: Current.account)
                  .order(:name)
  end

  def agent_payload(agent)
    account_user = normalized_account_user_for(agent)
    profile_assignment = profile_assignment_for(agent)

    {
      id: agent.id,
      name: agent.name,
      email: agent.email,
      role: account_user&.role,
      availability: account_user&.availability,
      availability_status: agent.availability_status,
      auto_offline: account_user&.auto_offline,
      confirmed: agent.confirmed?,
      provider: agent.provider,
      thumbnail: agent.avatar_url,
      profile_assignment_id: profile_assignment&.id,
      profile: profile_assignment&.role&.payload
    }
  end

  def update_avatar!(agent)
    agent.avatar.purge if ActiveModel::Type::Boolean.new.cast(agent_update_params[:remove_avatar]) && agent.avatar.attached?

    return if agent_update_params[:avatar].blank?

    Ibsoft::AgentProvisioning::AvatarAttacher.new(
      user: agent,
      avatar: agent_update_params[:avatar]
    ).perform
  end

  def account_user_update_params
    agent_update_params.slice(:role, :availability, :auto_offline).compact
  end

  def agent_user_update_params
    attributes = agent_update_params.slice(:name, :email).compact
    attributes[:name] = attributes[:name].to_s.strip if attributes.key?(:name)

    if attributes.key?(:email)
      attributes[:email] = attributes[:email].to_s.downcase.strip
      attributes[:uid] = attributes[:email] if attributes[:email].present? && agent.provider == 'email'
    end

    attributes
  end

  def normalized_account_user_for(agent)
    account_user = agent.account_users.find { |item| item.account_id == Current.account.id }
    Ibsoft::AgentProvisioning::AvailabilityNormalizer.new(account_user: account_user).perform
  end

  def profile_assignment_for(agent)
    profile_assignments_by_user_id[agent.id] ||
      Ibsoft::AccessControl::RoleAssignment
        .includes(:role)
        .find_by(account: Current.account, user: agent)
  end

  def profile_assignments_by_user_id
    @profile_assignments_by_user_id ||= Ibsoft::AccessControl::RoleAssignment
                                        .includes(:role)
                                        .where(account: Current.account, user_id: agents.map(&:id))
                                        .index_by(&:user_id)
  end
end

class Api::V1::Accounts::Ibsoft::ConversationDistribution::TeamPoliciesController <
  Api::V1::Accounts::Ibsoft::ConversationDistribution::BaseController
  before_action :fetch_team, only: [:show, :update]

  def show
    render json: policy.payload
  end

  def update
    policy.override_channel_policy = boolean_param(:override_channel_policy) if params.key?(:override_channel_policy)
    assign_policy_attributes(policy)
    policy.save!

    render json: policy.payload
  end

  def copy
    source_policy = find_team_policy!(params[:source_team_id], params[:source_policy_inbox_id])
    target_team = Current.account.teams.find(params[:target_team_id])
    target_inbox = find_optional_inbox(params[:target_policy_inbox_id])
    target_policy = Ibsoft::ConversationDistribution::TeamPolicy.find_or_initialize_by(
      account: Current.account,
      team: target_team,
      inbox: target_inbox
    )
    target_policy.assign_attributes(
      enabled: source_policy.enabled,
      override_channel_policy: source_policy.override_channel_policy,
      config: source_policy.config
    )
    target_policy.save!

    render json: target_policy.payload
  end

  private

  def policy
    @policy ||= Ibsoft::ConversationDistribution::TeamPolicy.find_or_initialize_by(
      account: Current.account,
      team: @team,
      inbox: optional_policy_inbox
    )
  end

  def find_team_policy!(team_id, inbox_id)
    team = Current.account.teams.find(team_id)
    inbox = find_optional_inbox(inbox_id)

    Ibsoft::ConversationDistribution::TeamPolicy.find_by!(
      account: Current.account,
      team: team,
      inbox: inbox
    )
  end

  def find_optional_inbox(inbox_id)
    return if inbox_id.blank?

    Current.account.inboxes.find(inbox_id)
  end
end

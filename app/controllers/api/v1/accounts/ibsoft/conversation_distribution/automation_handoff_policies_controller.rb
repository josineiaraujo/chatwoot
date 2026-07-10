class Api::V1::Accounts::Ibsoft::ConversationDistribution::AutomationHandoffPoliciesController <
  Api::V1::Accounts::Ibsoft::ConversationDistribution::BaseController
  before_action :fetch_inbox

  def show
    render json: policy.payload
  end

  def update
    policy.update!(policy_attributes)

    render json: policy.payload
  end

  private

  def policy
    @policy ||= Ibsoft::ConversationDistribution::AutomationHandoffPolicy.find_or_initialize_by(
      account: Current.account,
      inbox: @inbox
    )
  end

  def policy_attributes
    attrs = {}
    attrs[:enabled] = boolean_param(:enabled) if params.key?(:enabled)
    attrs[:stale_after_minutes] = params[:stale_after_minutes] if params.key?(:stale_after_minutes)
    attrs[:target_team] = target_team_from_param if params.key?(:target_team_id)
    attrs[:customer_message_enabled] = boolean_param(:customer_message_enabled) if params.key?(:customer_message_enabled)
    attrs[:customer_message] = params[:customer_message] if params.key?(:customer_message)
    attrs
  end

  def target_team_from_param
    return if params[:target_team_id].blank?

    Current.account.teams.find(params[:target_team_id])
  end
end

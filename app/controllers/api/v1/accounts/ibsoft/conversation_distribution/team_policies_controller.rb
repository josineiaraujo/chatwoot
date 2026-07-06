class Api::V1::Accounts::Ibsoft::ConversationDistribution::TeamPoliciesController <
  Api::V1::Accounts::Ibsoft::ConversationDistribution::BaseController
  before_action :fetch_team, only: [:show, :update]

  def show
    render json: policy.payload
  end

  def update
    policy.override_channel_policy = boolean_param(:override_channel_policy) if params.key?(:override_channel_policy)
    assign_distribution_policy(policy)
    policy.save!

    render json: policy.payload
  end

  private

  def policy
    @policy ||= Ibsoft::ConversationDistribution::TeamPolicy.find_or_initialize_by(
      account: Current.account,
      team: @team,
      inbox: optional_policy_inbox
    )
  end
end

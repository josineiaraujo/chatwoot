class Api::V1::Accounts::Ibsoft::ConversationDistribution::InboxPoliciesController <
  Api::V1::Accounts::Ibsoft::ConversationDistribution::BaseController
  before_action :fetch_inbox

  def show
    render json: policy.payload
  end

  def update
    assign_policy_attributes(policy)
    policy.save!

    render json: policy.payload
  end

  private

  def policy
    @policy ||= Ibsoft::ConversationDistribution::ChannelPolicy.find_or_initialize_by(
      account: Current.account,
      inbox: @inbox
    )
  end
end

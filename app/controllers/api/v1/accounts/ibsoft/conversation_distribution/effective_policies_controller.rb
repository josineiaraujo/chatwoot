class Api::V1::Accounts::Ibsoft::ConversationDistribution::EffectivePoliciesController <
  Api::V1::Accounts::Ibsoft::ConversationDistribution::BaseController
  def show
    inbox = Current.account.inboxes.find(params[:inbox_id])
    team = Current.account.teams.find(params[:team_id]) if params[:team_id].present?

    policy = Ibsoft::ConversationDistribution::EffectivePolicyResolver.new(
      account: Current.account,
      inbox: inbox,
      team: team
    ).perform

    render json: policy
  end
end

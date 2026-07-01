class Api::V1::Accounts::Ibsoft::ConversationDistribution::ExecutionsController <
  Api::V1::Accounts::Ibsoft::ConversationDistribution::BaseController
  def create
    render json: Ibsoft::ConversationDistribution::AssignmentExecutor.new(
      account: Current.account,
      inbox_id: params[:inbox_id],
      team_id: params[:team_id],
      limit: params[:limit]
    ).perform
  end
end

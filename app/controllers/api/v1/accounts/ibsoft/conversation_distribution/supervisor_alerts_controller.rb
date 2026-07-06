class Api::V1::Accounts::Ibsoft::ConversationDistribution::SupervisorAlertsController <
  Api::V1::Accounts::Ibsoft::ConversationDistribution::ReadOnlyController
  def index
    render json: Ibsoft::ConversationDistribution::SupervisorAlertFinder.new(
      account: Current.account,
      inbox_id: params[:inbox_id],
      team_id: params[:team_id],
      limit: params[:limit]
    ).perform
  end
end

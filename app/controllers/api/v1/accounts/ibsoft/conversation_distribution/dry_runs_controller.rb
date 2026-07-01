class Api::V1::Accounts::Ibsoft::ConversationDistribution::DryRunsController <
  Api::V1::Accounts::Ibsoft::ConversationDistribution::BaseController
  def index
    render json: Ibsoft::ConversationDistribution::DryRunPreview.new(
      account: Current.account,
      inbox_id: params[:inbox_id],
      team_id: params[:team_id],
      limit: params[:limit]
    ).perform
  end
end

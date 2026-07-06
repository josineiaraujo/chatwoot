class Api::V1::Accounts::Ibsoft::ConversationDistribution::AgentAssignmentsController < Api::V1::Accounts::BaseController
  def index
    render json: Ibsoft::ConversationDistribution::AgentAssignmentPreview.new(
      account: Current.account,
      user: Current.user,
      limit: params[:limit]
    ).perform
  end

  def claim
    render json: Ibsoft::ConversationDistribution::AgentAssignmentClaimer.new(
      account: Current.account,
      user: Current.user,
      conversation_ids: params[:conversation_ids]
    ).perform
  end
end

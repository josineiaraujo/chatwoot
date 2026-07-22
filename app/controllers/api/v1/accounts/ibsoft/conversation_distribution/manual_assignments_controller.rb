class Api::V1::Accounts::Ibsoft::ConversationDistribution::ManualAssignmentsController <
      Api::V1::Accounts::Conversations::BaseController
  rescue_from Ibsoft::ConversationDistribution::ManualAssignmentService::Error, with: :render_assignment_error

  def create
    @result = Ibsoft::ConversationDistribution::ManualAssignmentService.new(
      conversation: @conversation,
      actor: Current.user,
      assignment_type: params.require(:assignment_type),
      target_id: params[:target_id]
    ).perform
  end

  private

  def render_assignment_error(error)
    render json: { error: error.code }, status: :unprocessable_content
  end
end

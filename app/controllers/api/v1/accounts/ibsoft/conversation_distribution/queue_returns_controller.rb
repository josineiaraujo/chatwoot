class Api::V1::Accounts::Ibsoft::ConversationDistribution::QueueReturnsController <
      Api::V1::Accounts::Conversations::BaseController
  rescue_from Ibsoft::ConversationDistribution::QueueReturnService::Error, with: :render_queue_return_error

  def create
    result = Ibsoft::ConversationDistribution::QueueReturnService.new(
      conversation: @conversation,
      actor: Current.user,
      team: target_team
    ).perform

    render json: response_payload(result)
  end

  private

  def target_team
    @target_team ||= Current.account.teams.find(params.require(:team_id))
  end

  def response_payload(result)
    {
      queued: result[:queued],
      conversation_id: result[:conversation_id],
      display_id: result[:display_id],
      event_id: result[:event_id],
      team: {
        id: result[:team].id,
        name: result[:team].name
      }
    }
  end

  def render_queue_return_error(error)
    render json: { error: error.code }, status: :unprocessable_content
  end
end

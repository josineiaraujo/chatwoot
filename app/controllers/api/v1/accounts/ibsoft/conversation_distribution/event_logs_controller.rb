class Api::V1::Accounts::Ibsoft::ConversationDistribution::EventLogsController <
  Api::V1::Accounts::Ibsoft::ConversationDistribution::ReadOnlyController
  def index
    render json: Ibsoft::ConversationDistribution::EventLogFinder.new(
      account: Current.account,
      filters: params.permit(
        :event_type,
        :reason,
        :conversation_id,
        :inbox_id,
        :team_id,
        :previous_assignee_id,
        :new_assignee_id,
        :since,
        :until,
        :page,
        :limit
      )
    ).perform
  end
end

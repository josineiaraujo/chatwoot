class Api::V1::Accounts::Ibsoft::BusinessCalendar::CalendarTeamLinksController <
  Api::V1::Accounts::Ibsoft::BusinessCalendar::BaseController
  before_action :set_calendar

  def update
    calendar = Ibsoft::BusinessCalendar::CalendarTeamLinksUpdater.new(
      account: Current.account,
      calendar: @calendar,
      team_ids: team_ids
    ).perform

    render json: calendar.payload(include_holidays: true)
  end

  private

  def team_ids
    raise ActionController::ParameterMissing, :team_ids unless params.key?(:team_ids)

    params.permit(team_ids: []).fetch(:team_ids, [])
  end
end

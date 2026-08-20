class Api::V1::Accounts::Ibsoft::BusinessCalendar::TeamLinksController <
  Api::V1::Accounts::Ibsoft::BusinessCalendar::BaseController
  before_action :set_team

  def show
    render json: team_link&.payload || { team_id: @team.id, business_calendar_id: nil }
  end

  def update
    link = update_team_link(params.require(:business_calendar_id))
    render json: link.payload
  end

  def destroy
    team_link&.destroy!
    head :no_content
  end

  private

  def set_team
    @team = Current.account.teams.find(params[:team_id])
  end

  def team_link
    @team_link ||= Ibsoft::BusinessCalendar::TeamLink.find_by(account: Current.account, team: @team)
  end

  def update_team_link(business_calendar_id)
    Ibsoft::BusinessCalendar::TeamLinkUpdater.new(
      account: Current.account,
      team: @team,
      business_calendar_id: business_calendar_id
    ).perform
  end
end

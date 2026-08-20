class Ibsoft::BusinessCalendar::TeamLinkUpdater
  def initialize(account:, team:, business_calendar_id:)
    @account = account
    @team = team
    @business_calendar_id = business_calendar_id
  end

  def perform
    Ibsoft::BusinessCalendar::TeamLink.transaction do
      locked_team = account.teams.lock.find(team.id)
      next remove_link(locked_team) if business_calendar_id.blank?

      update_link(locked_team)
    end
  end

  private

  attr_reader :account, :team, :business_calendar_id

  def update_link(locked_team)
    calendar = Ibsoft::BusinessCalendar::Calendar.find_by!(
      account: account,
      id: business_calendar_id
    )
    link = Ibsoft::BusinessCalendar::TeamLink.lock.find_or_initialize_by(
      account: account,
      team: locked_team
    )
    link.update!(business_calendar: calendar)
    link
  end

  def remove_link(locked_team)
    Ibsoft::BusinessCalendar::TeamLink.lock.find_by(account: account, team: locked_team)&.destroy!
    nil
  end
end

class Ibsoft::BusinessCalendar::CalendarTeamLinksUpdater
  def initialize(account:, calendar:, team_ids:)
    @account = account
    @calendar = calendar
    @team_ids = normalize_team_ids(team_ids)
  end

  def perform
    Ibsoft::BusinessCalendar::TeamLink.transaction do
      lock_calendar
      teams = lock_affected_teams
      selected_teams = team_ids.filter_map { |team_id| teams[team_id] }
      ensure_all_teams_belong_to_account!(selected_teams)

      remove_unselected_links
      selected_teams.each { |team| link_team(team) }
    end

    calendar.reload
  end

  private

  attr_reader :account, :calendar, :team_ids

  def lock_calendar
    Ibsoft::BusinessCalendar::Calendar.where(account: account, id: calendar.id).lock.first!
  end

  def lock_affected_teams
    existing_team_ids = Ibsoft::BusinessCalendar::TeamLink.where(
      account: account,
      business_calendar: calendar
    ).pluck(:team_id)
    affected_team_ids = (team_ids + existing_team_ids).uniq.sort

    account.teams.where(id: affected_team_ids).order(:id).lock.index_by(&:id)
  end

  def normalize_team_ids(values)
    Array(values).filter_map do |value|
      Integer(value.to_s, 10) if value.to_s.present?
    rescue ArgumentError
      raise ActiveRecord::RecordNotFound, "Invalid team id: #{value.inspect}"
    end.uniq.sort
  end

  def ensure_all_teams_belong_to_account!(teams)
    return if teams.map(&:id) == team_ids

    raise ActiveRecord::RecordNotFound, 'One or more teams were not found in this account'
  end

  def remove_unselected_links
    links = Ibsoft::BusinessCalendar::TeamLink.where(account: account, business_calendar: calendar)
    links = links.where.not(team_id: team_ids) if team_ids.any?
    links.destroy_all
  end

  def link_team(team)
    link = Ibsoft::BusinessCalendar::TeamLink.find_or_initialize_by(account: account, team: team)
    link.update!(business_calendar: calendar)
  end
end

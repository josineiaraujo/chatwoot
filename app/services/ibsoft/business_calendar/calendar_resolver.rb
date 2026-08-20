class Ibsoft::BusinessCalendar::CalendarResolver
  pattr_initialize [:account!, :team!]

  def perform
    calendar_id = Ibsoft::BusinessCalendar::Cache.calendar_id_for_team(account.id, team.id)
    return if calendar_id.blank?

    Ibsoft::BusinessCalendar::Calendar.find_by(id: calendar_id, account_id: account.id)
  end
end

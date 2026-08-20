class Ibsoft::BusinessCalendar::HolidayResolver
  pattr_initialize [:account!, :team!, :date!]

  def perform
    calendar = Ibsoft::BusinessCalendar::CalendarResolver.new(account: account, team: team).perform
    return if calendar.blank?

    Ibsoft::BusinessCalendar::Cache.holiday(calendar.id, date)
  end
end

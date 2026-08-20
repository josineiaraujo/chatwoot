class Ibsoft::BusinessCalendar::Cache
  TTL = 12.hours

  class << self
    def calendar_id_for_team(account_id, team_id)
      Rails.cache.fetch(team_key(account_id, team_id), expires_in: TTL) do
        Ibsoft::BusinessCalendar::TeamLink.where(account_id: account_id, team_id: team_id)
                                          .pick(:business_calendar_id)
      end
    end

    def holiday(calendar_id, date)
      Rails.cache.fetch(holiday_key(calendar_id, date), expires_in: TTL) do
        record = Ibsoft::BusinessCalendar::Holiday.find_by(
          business_calendar_id: calendar_id,
          holiday_date: date
        )
        record && {
          id: record.id,
          business_calendar_id: record.business_calendar_id,
          holiday_date: record.holiday_date.iso8601,
          name: record.name,
          holiday_kind: record.holiday_kind,
          source_scope: record.source_scope,
          state_code: record.state_code
        }
      end
    end

    def invalidate_team(account_id, team_id)
      Rails.cache.delete(team_key(account_id, team_id))
    end

    def invalidate_holiday(calendar_id, date)
      Rails.cache.delete(holiday_key(calendar_id, date))
    end

    private

    def team_key(account_id, team_id)
      "ibsoft:business_calendar:account:#{account_id}:team:#{team_id}"
    end

    def holiday_key(calendar_id, date)
      "ibsoft:business_calendar:#{calendar_id}:holiday:#{date.to_date.iso8601}"
    end
  end
end

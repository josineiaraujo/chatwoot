class SetIbsoftDefaultTimezone < ActiveRecord::Migration[7.1]
  DEFAULT_TIMEZONE = 'America/Sao_Paulo'.freeze

  def up
    change_column_default :inboxes, :timezone, from: 'UTC', to: DEFAULT_TIMEZONE
    update_legacy_inbox_timezones
    update_legacy_account_timezones
  end

  def down
    change_column_default :inboxes, :timezone, from: DEFAULT_TIMEZONE, to: 'UTC'
    restore_utc_inbox_timezones
    remove_ibsoft_account_timezones
  end

  private

  def update_legacy_inbox_timezones
    execute <<~SQL.squish
      UPDATE inboxes
      SET timezone = '#{DEFAULT_TIMEZONE}', updated_at = NOW()
      WHERE timezone IS NULL
         OR timezone = ''
         OR timezone IN ('UTC', 'America/Los_Angeles')
    SQL
  end

  def update_legacy_account_timezones
    execute <<~SQL.squish
      UPDATE accounts
      SET settings = jsonb_set(
            COALESCE(settings, '{}'::jsonb),
            '{reporting_timezone}',
            to_jsonb('#{DEFAULT_TIMEZONE}'::text),
            true
          ),
          updated_at = NOW()
      WHERE settings IS NULL
         OR settings ->> 'reporting_timezone' IS NULL
         OR settings ->> 'reporting_timezone' = ''
         OR settings ->> 'reporting_timezone' IN ('UTC', 'America/Los_Angeles')
    SQL
  end

  def restore_utc_inbox_timezones
    execute <<~SQL.squish
      UPDATE inboxes
      SET timezone = 'UTC', updated_at = NOW()
      WHERE timezone = '#{DEFAULT_TIMEZONE}'
    SQL
  end

  def remove_ibsoft_account_timezones
    execute <<~SQL.squish
      UPDATE accounts
      SET settings = settings - 'reporting_timezone', updated_at = NOW()
      WHERE settings ->> 'reporting_timezone' = '#{DEFAULT_TIMEZONE}'
    SQL
  end
end

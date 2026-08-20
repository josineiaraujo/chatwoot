class CreateIbsoftBusinessCalendarsAndAfterHoursPolicies < ActiveRecord::Migration[7.1]
  def change
    create_business_calendars
    create_business_holidays
    create_business_calendar_team_links
    create_after_hours_policies
    create_after_hours_waits
    add_after_hours_policy_to_distribution_policies
  end

  private

  def create_business_calendars
    create_table :ibsoft_business_calendars do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.timestamps
    end
    add_index :ibsoft_business_calendars, [:account_id, :name],
              unique: true, name: 'idx_ibsoft_business_calendars_account_name'
  end

  def create_business_holidays
    create_table :ibsoft_business_holidays do |t|
      t.references :business_calendar, null: false,
                                       foreign_key: { to_table: :ibsoft_business_calendars, on_delete: :cascade },
                                       index: { name: 'idx_ibsoft_business_holidays_calendar' }
      t.date :holiday_date, null: false
      t.string :name, null: false
      t.string :holiday_kind, null: false, default: 'holiday'
      t.string :source, null: false, default: 'manual'
      t.string :source_scope, null: false, default: 'manual'
      t.string :state_code
      t.timestamps
    end
    add_index :ibsoft_business_holidays, [:business_calendar_id, :holiday_date],
              unique: true, name: 'idx_ibsoft_business_holidays_calendar_date'
  end

  def create_business_calendar_team_links
    create_table :ibsoft_business_calendar_team_links do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :business_calendar, null: false,
                                       foreign_key: { to_table: :ibsoft_business_calendars, on_delete: :cascade },
                                       index: { name: 'idx_ibsoft_calendar_team_links_calendar' }
      t.references :team, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :ibsoft_business_calendar_team_links, [:account_id, :team_id],
              unique: true, name: 'idx_ibsoft_calendar_team_links_account_team'
  end

  def create_after_hours_policies
    create_table :ibsoft_after_hours_policies do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.boolean :enabled, null: false, default: false
      t.string :exit_command, null: false, default: 'sair'
      t.text :regular_message
      t.text :holiday_message
      t.text :exit_confirmation_message
      t.timestamps
    end
    add_index :ibsoft_after_hours_policies, [:account_id, :name],
              unique: true, name: 'idx_ibsoft_after_hours_policies_account_name'
  end

  def create_after_hours_waits
    create_table :ibsoft_after_hours_waits do |t|
      add_after_hours_wait_references(t)
      t.string :status, null: false, default: 'active'
      t.string :cause, null: false
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps
    end
    add_index :ibsoft_after_hours_waits, [:account_id, :status], name: 'idx_ibsoft_after_hours_waits_account_status'
  end

  def add_after_hours_wait_references(table)
    table.references :account, null: false, foreign_key: { on_delete: :cascade }
    table.references :conversation, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
    table.references :after_hours_policy, null: false,
                                          foreign_key: { to_table: :ibsoft_after_hours_policies, on_delete: :cascade },
                                          index: { name: 'idx_ibsoft_after_hours_waits_policy' }
    table.references :team, foreign_key: { on_delete: :nullify }
    add_after_hours_wait_context_references(table)
    add_after_hours_wait_message_references(table)
  end

  def add_after_hours_wait_context_references(table)
    table.references :business_calendar,
                     foreign_key: { to_table: :ibsoft_business_calendars, on_delete: :nullify },
                     index: { name: 'idx_ibsoft_after_hours_waits_calendar' }
    table.references :business_holiday,
                     foreign_key: { to_table: :ibsoft_business_holidays, on_delete: :nullify },
                     index: { name: 'idx_ibsoft_after_hours_waits_holiday' }
  end

  def add_after_hours_wait_message_references(table)
    table.references :entry_message,
                     foreign_key: { to_table: :messages, on_delete: :nullify },
                     index: { name: 'idx_ibsoft_after_hours_waits_entry_message' }
    table.references :exit_message,
                     foreign_key: { to_table: :messages, on_delete: :nullify },
                     index: { name: 'idx_ibsoft_after_hours_waits_exit_message' }
  end

  def add_after_hours_policy_to_distribution_policies
    add_reference :ibsoft_conversation_distribution_policies, :after_hours_policy,
                  foreign_key: { to_table: :ibsoft_after_hours_policies, on_delete: :nullify },
                  index: { name: 'idx_ibsoft_distribution_policies_after_hours' }
  end
end

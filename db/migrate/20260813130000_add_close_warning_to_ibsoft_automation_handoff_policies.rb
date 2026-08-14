class AddCloseWarningToIbsoftAutomationHandoffPolicies < ActiveRecord::Migration[7.1]
  POLICY_TABLE = :ibsoft_conversation_distribution_automation_handoff_policies
  SCHEDULE_TABLE = :ibsoft_conversation_distribution_automation_close_schedules

  def up
    add_policy_fields
    create_schedule_table
    add_schedule_indexes
    migrate_existing_close_messages
  end

  def down
    drop_table SCHEDULE_TABLE
    remove_column POLICY_TABLE, :close_final_message
    remove_column POLICY_TABLE, :close_final_message_enabled
    remove_column POLICY_TABLE, :close_warning_delay_minutes
    remove_column POLICY_TABLE, :close_warning_message
    remove_column POLICY_TABLE, :close_warning_enabled
  end

  private

  def add_policy_fields
    add_column POLICY_TABLE, :close_warning_enabled, :boolean, null: false, default: false
    add_column POLICY_TABLE, :close_warning_message, :text
    add_column POLICY_TABLE, :close_warning_delay_minutes, :integer, null: false, default: 1
    add_column POLICY_TABLE, :close_final_message_enabled, :boolean, null: false, default: false
    add_column POLICY_TABLE, :close_final_message, :text
  end

  def create_schedule_table
    create_table SCHEDULE_TABLE do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :automation_handoff_policy,
                   null: false,
                   foreign_key: { to_table: POLICY_TABLE, on_delete: :cascade },
                   index: false
      t.bigint :trigger_message_id, null: false
      t.bigint :warning_message_id, null: false
      t.datetime :close_at, null: false
      t.timestamps
    end
  end

  def add_schedule_indexes
    add_index SCHEDULE_TABLE, :conversation_id, unique: true, name: 'idx_ibsoft_auto_close_schedule_conversation'
    add_index SCHEDULE_TABLE, [:account_id, :close_at], name: 'idx_ibsoft_auto_close_schedule_due'
    add_index SCHEDULE_TABLE, :automation_handoff_policy_id, name: 'idx_ibsoft_auto_close_schedule_policy'
  end

  def migrate_existing_close_messages
    execute <<~SQL.squish
      UPDATE #{POLICY_TABLE}
      SET close_final_message_enabled = customer_message_enabled,
          close_final_message = customer_message
      WHERE timeout_action = 'close_conversation'
        AND customer_message_enabled = TRUE
    SQL
  end
end

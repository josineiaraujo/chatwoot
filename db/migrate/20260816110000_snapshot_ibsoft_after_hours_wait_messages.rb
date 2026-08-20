class SnapshotIbsoftAfterHoursWaitMessages < ActiveRecord::Migration[7.1]
  def up
    add_column :ibsoft_after_hours_waits, :exit_command, :string
    add_column :ibsoft_after_hours_waits, :exit_confirmation_message, :text

    execute <<~SQL.squish
      UPDATE ibsoft_after_hours_waits AS waits
      SET exit_command = COALESCE(policies.exit_command, 'sair'),
          exit_confirmation_message = COALESCE(policies.exit_confirmation_message, '')
      FROM ibsoft_after_hours_policies AS policies
      WHERE policies.id = waits.after_hours_policy_id
    SQL

    change_column_null :ibsoft_after_hours_waits, :exit_command, false
    change_column_null :ibsoft_after_hours_waits, :exit_confirmation_message, false
  end

  def down
    remove_column :ibsoft_after_hours_waits, :exit_confirmation_message
    remove_column :ibsoft_after_hours_waits, :exit_command
  end
end

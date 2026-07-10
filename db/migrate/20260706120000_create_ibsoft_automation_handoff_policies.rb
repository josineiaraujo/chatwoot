class CreateIbsoftAutomationHandoffPolicies < ActiveRecord::Migration[7.1]
  def change
    create_table :ibsoft_conversation_distribution_automation_handoff_policies do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.references :target_team, foreign_key: { to_table: :teams }
      t.boolean :enabled, null: false, default: false
      t.integer :stale_after_minutes, null: false, default: 10
      t.boolean :customer_message_enabled, null: false, default: false
      t.text :customer_message

      t.timestamps
    end

    add_index :ibsoft_conversation_distribution_automation_handoff_policies,
              [:account_id, :inbox_id],
              unique: true,
              name: 'idx_ibsoft_automation_handoff_account_inbox'
    add_index :ibsoft_conversation_distribution_automation_handoff_policies,
              [:account_id, :enabled],
              name: 'idx_ibsoft_automation_handoff_account_enabled'
  end
end

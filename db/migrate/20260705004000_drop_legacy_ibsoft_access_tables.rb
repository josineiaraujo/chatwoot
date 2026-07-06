class DropLegacyIbsoftAccessTables < ActiveRecord::Migration[7.1]
  def up
    drop_table :ibsoft_chathub_settings_managers, if_exists: true
    drop_table :ibsoft_conversation_distribution_supervisors, if_exists: true
  end

  def down
    create_table :ibsoft_chathub_settings_managers, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :ibsoft_chathub_settings_managers,
              [:account_id, :user_id],
              unique: true,
              name: 'idx_ibsoft_chathub_settings_manager',
              if_not_exists: true

    create_table :ibsoft_conversation_distribution_supervisors, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :ibsoft_conversation_distribution_supervisors,
              [:account_id, :user_id],
              unique: true,
              name: 'idx_ibsoft_distribution_supervisor',
              if_not_exists: true
  end
end

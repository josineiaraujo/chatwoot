class CreateIbsoftChathubSettings < ActiveRecord::Migration[7.1]
  def change
    create_settings_table
    create_managers_table
    create_agent_presence_states_table
  end

  private

  def create_settings_table
    create_table :ibsoft_chathub_settings do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :config, null: false, default: {}

      t.timestamps
    end
  end

  def create_managers_table
    create_table :ibsoft_chathub_settings_managers do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :ibsoft_chathub_settings_managers,
              [:account_id, :user_id],
              unique: true,
              name: 'idx_ibsoft_chathub_settings_manager'
  end

  def create_agent_presence_states_table
    create_table :ibsoft_chathub_agent_presence_states do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :current_status, null: false, default: 'offline'
      t.datetime :last_status_changed_at
      t.datetime :last_online_at
      t.datetime :last_offline_at

      t.timestamps
    end

    add_index :ibsoft_chathub_agent_presence_states,
              [:account_id, :user_id],
              unique: true,
              name: 'idx_ibsoft_chathub_agent_presence_state'
  end
end

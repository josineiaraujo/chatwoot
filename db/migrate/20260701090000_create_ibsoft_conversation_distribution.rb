class CreateIbsoftConversationDistribution < ActiveRecord::Migration[7.1]
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def change
    create_table :ibsoft_conversation_distribution_channel_policies do |t|
      t.references :account, null: false, index: true
      t.references :inbox, null: false, index: true
      t.boolean :enabled, null: false, default: false
      t.jsonb :config, null: false, default: {}

      t.timestamps
    end

    add_index :ibsoft_conversation_distribution_channel_policies,
              [:account_id, :inbox_id],
              unique: true,
              name: 'idx_ibsoft_distribution_channel_policy'

    create_table :ibsoft_conversation_distribution_team_policies do |t|
      t.references :account, null: false, index: true
      t.references :team, null: false, index: true
      t.references :inbox, index: true
      t.boolean :enabled, null: false, default: false
      t.boolean :override_channel_policy, null: false, default: false
      t.jsonb :config, null: false, default: {}

      t.timestamps
    end

    add_index :ibsoft_conversation_distribution_team_policies,
              [:account_id, :team_id],
              unique: true,
              where: 'inbox_id IS NULL',
              name: 'idx_ibsoft_distribution_team_policy'
    add_index :ibsoft_conversation_distribution_team_policies,
              [:account_id, :team_id, :inbox_id],
              unique: true,
              where: 'inbox_id IS NOT NULL',
              name: 'idx_ibsoft_distribution_team_inbox_policy'

    create_table :ibsoft_conversation_distribution_event_logs do |t|
      t.references :account, null: false, index: true
      t.references :conversation, index: true
      t.references :inbox, index: true
      t.references :team, index: true
      t.references :previous_assignee, index: true
      t.references :new_assignee, index: true
      t.string :event_type, null: false
      t.string :reason
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :ibsoft_conversation_distribution_event_logs,
              [:account_id, :created_at],
              name: 'idx_ibsoft_distribution_events_account_created'
    add_index :ibsoft_conversation_distribution_event_logs,
              [:conversation_id, :created_at],
              name: 'idx_ibsoft_distribution_events_conversation_created'
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end

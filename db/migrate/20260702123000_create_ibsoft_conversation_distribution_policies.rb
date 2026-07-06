class CreateIbsoftConversationDistributionPolicies < ActiveRecord::Migration[7.1]
  def change
    create_table :ibsoft_conversation_distribution_policies do |t|
      t.references :account, null: false, foreign_key: true, index: { name: 'idx_ibsoft_distribution_policies_account' }
      t.string :name, null: false
      t.boolean :enabled, null: false, default: false
      t.jsonb :config, null: false, default: {}

      t.timestamps
    end

    add_index :ibsoft_conversation_distribution_policies,
              [:account_id, :name],
              unique: true,
              name: 'idx_ibsoft_distribution_policies_account_name'

    add_reference :ibsoft_conversation_distribution_channel_policies,
                  :distribution_policy,
                  foreign_key: { to_table: :ibsoft_conversation_distribution_policies },
                  index: { name: 'idx_ibsoft_channel_policy_distribution_policy' }

    add_reference :ibsoft_conversation_distribution_team_policies,
                  :distribution_policy,
                  foreign_key: { to_table: :ibsoft_conversation_distribution_policies },
                  index: { name: 'idx_ibsoft_team_policy_distribution_policy' }
  end
end

class CreateIbsoftConversationDistributionSupervisors < ActiveRecord::Migration[7.1]
  def change
    create_table :ibsoft_conversation_distribution_supervisors do |t|
      t.references :account, null: false, index: true
      t.references :user, null: false, index: true
      t.references :created_by, index: true

      t.timestamps
    end

    add_index :ibsoft_conversation_distribution_supervisors,
              [:account_id, :user_id],
              unique: true,
              name: 'idx_ibsoft_distribution_supervisor'
  end
end

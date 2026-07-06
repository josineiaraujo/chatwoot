class CreateIbsoftAccessControl < ActiveRecord::Migration[7.0]
  def change
    create_table :ibsoft_access_control_roles do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :description
      t.text :permissions, array: true, default: [], null: false
      t.timestamps
    end

    add_index :ibsoft_access_control_roles,
              [:account_id, :name],
              unique: true,
              name: 'idx_ibsoft_access_control_roles_account_name'

    create_table :ibsoft_access_control_role_assignments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :role,
                   null: false,
                   foreign_key: { to_table: :ibsoft_access_control_roles },
                   index: { name: 'idx_ibsoft_access_assignments_role_id' }
      t.references :user, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :ibsoft_access_control_role_assignments,
              [:account_id, :user_id],
              unique: true,
              name: 'idx_ibsoft_access_assignments_account_user'
  end
end

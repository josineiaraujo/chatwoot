class CreateIbsoftErpConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :ibsoft_erp_connections do |t|
      add_connection_columns(t)
      t.timestamps
    end

    add_connection_indexes
  end

  private

  def add_connection_columns(table)
    table.references :account, null: false, foreign_key: true
    table.string :name, null: false
    table.string :provider, null: false
    table.string :auth_type, null: false
    table.string :base_url, null: false
    table.boolean :active, null: false, default: false
    table.text :credentials, null: false, default: '{}'
    table.jsonb :settings, null: false, default: {}
    table.datetime :last_tested_at
    table.string :last_test_status
  end

  def add_connection_indexes
    add_index :ibsoft_erp_connections, [:account_id, :provider, :name],
              unique: true,
              name: 'idx_ibsoft_erp_connections_account_provider_name'
    add_index :ibsoft_erp_connections, [:account_id, :active],
              unique: true,
              where: 'active = true',
              name: 'idx_ibsoft_erp_connections_one_active'
  end
end

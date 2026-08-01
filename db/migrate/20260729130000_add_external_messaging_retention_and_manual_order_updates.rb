class AddExternalMessagingRetentionAndManualOrderUpdates < ActiveRecord::Migration[7.1]
  def change
    add_retention_policy
    add_manual_update_audit
    add_query_indexes
  end

  private

  def add_retention_policy
    add_column :ibsoft_external_message_endpoints,
               :retention_days,
               :integer,
               null: false,
               default: 30
    add_check_constraint :ibsoft_external_message_endpoints,
                         'retention_days BETWEEN 1 AND 3650',
                         name: 'chk_ibsoft_ext_endpoints_retention_days'
  end

  def add_manual_update_audit
    add_column :ibsoft_external_message_order_updates,
               :source,
               :string,
               null: false,
               default: 'external_api'
    add_reference :ibsoft_external_message_order_updates,
                  :requested_by,
                  foreign_key: { to_table: :users },
                  index: { name: 'idx_ibsoft_ext_order_updates_requested_by' }
    add_check_constraint :ibsoft_external_message_order_updates,
                         "source IN ('external_api', 'manual')",
                         name: 'chk_ibsoft_ext_order_updates_source'
  end

  def add_query_indexes
    add_index :ibsoft_external_message_deliveries,
              [:endpoint_id, :created_at],
              name: 'idx_ibsoft_ext_deliveries_endpoint_created'
    add_index :ibsoft_external_message_deliveries,
              [:endpoint_id, :recipient, :created_at],
              name: 'idx_ibsoft_ext_deliveries_endpoint_recipient'
    add_index :ibsoft_external_message_orders,
              [:account_id, :order_status, :payment_status, :created_at],
              name: 'idx_ibsoft_ext_orders_account_status_created'
  end
end

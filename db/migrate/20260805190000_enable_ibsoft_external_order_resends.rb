class EnableIbsoftExternalOrderResends < ActiveRecord::Migration[7.1]
  OLD_REFERENCE_INDEX = 'idx_ibsoft_ext_orders_tenant_reference'.freeze
  ENDPOINT_REFERENCE_INDEX = 'idx_ibsoft_ext_orders_endpoint_reference'.freeze
  DELIVERY_ORDER_INDEX = 'idx_ibsoft_ext_deliveries_order'.freeze

  def up
    add_column :ibsoft_external_message_endpoints,
               :allow_order_resends,
               :boolean,
               null: false,
               default: true

    add_order_endpoint
    replace_order_reference_index
    add_delivery_order
  end

  def down
    remove_foreign_key :ibsoft_external_message_deliveries,
                       :ibsoft_external_message_orders
    remove_index :ibsoft_external_message_deliveries, name: DELIVERY_ORDER_INDEX
    remove_column :ibsoft_external_message_deliveries, :order_id

    remove_index :ibsoft_external_message_orders, name: ENDPOINT_REFERENCE_INDEX
    add_index :ibsoft_external_message_orders,
              [:account_id, :inbox_id, :reference_id],
              unique: true,
              name: OLD_REFERENCE_INDEX

    remove_foreign_key :ibsoft_external_message_orders,
                       :ibsoft_external_message_endpoints
    remove_column :ibsoft_external_message_orders, :endpoint_id
    remove_column :ibsoft_external_message_endpoints, :allow_order_resends
  end

  private

  def add_order_endpoint
    add_reference :ibsoft_external_message_orders,
                  :endpoint,
                  null: true,
                  foreign_key: { to_table: :ibsoft_external_message_endpoints },
                  index: false

    execute <<~SQL.squish
      UPDATE ibsoft_external_message_orders AS orders
      SET endpoint_id = deliveries.endpoint_id
      FROM ibsoft_external_message_deliveries AS deliveries
      WHERE deliveries.id = orders.opening_delivery_id
    SQL

    change_column_null :ibsoft_external_message_orders, :endpoint_id, false
  end

  def replace_order_reference_index
    remove_index :ibsoft_external_message_orders, name: OLD_REFERENCE_INDEX
    add_index :ibsoft_external_message_orders,
              [:endpoint_id, :reference_id],
              unique: true,
              name: ENDPOINT_REFERENCE_INDEX
  end

  def add_delivery_order
    add_reference :ibsoft_external_message_deliveries,
                  :order,
                  null: true,
                  foreign_key: {
                    to_table: :ibsoft_external_message_orders,
                    on_delete: :nullify
                  },
                  index: { name: DELIVERY_ORDER_INDEX }

    execute <<~SQL.squish
      UPDATE ibsoft_external_message_deliveries AS deliveries
      SET order_id = orders.id
      FROM ibsoft_external_message_orders AS orders
      WHERE deliveries.endpoint_id = orders.endpoint_id
        AND deliveries.order_reference_id = orders.reference_id
        AND deliveries.template_type = 'order'
    SQL
  end
end

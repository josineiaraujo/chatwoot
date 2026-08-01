class CreateIbsoftExternalMessageOrders < ActiveRecord::Migration[7.1]
  def up
    create_orders
    backfill_orders
    create_order_updates
  end

  def down
    drop_table :ibsoft_external_message_order_updates
    drop_table :ibsoft_external_message_orders
  end

  private

  def create_orders
    create_table :ibsoft_external_message_orders do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.references :opening_delivery,
                   null: false,
                   foreign_key: { to_table: :ibsoft_external_message_deliveries },
                   index: { unique: true, name: 'idx_ibsoft_ext_orders_opening_delivery' }
      t.string :reference_id, null: false
      t.string :order_status, null: false, default: 'pending'
      t.string :payment_status
      t.timestamps
    end

    add_index :ibsoft_external_message_orders,
              [:account_id, :inbox_id, :reference_id],
              unique: true,
              name: 'idx_ibsoft_ext_orders_tenant_reference'
    add_order_constraints
  end

  def add_order_constraints
    add_check_constraint :ibsoft_external_message_orders,
                         "order_status IN ('pending', 'processing', 'partially_shipped', " \
                         "'shipped', 'completed', 'canceled')",
                         name: 'chk_ibsoft_ext_orders_order_status'
    add_check_constraint :ibsoft_external_message_orders,
                         "payment_status IS NULL OR payment_status IN ('pending', 'captured', 'failed')",
                         name: 'chk_ibsoft_ext_orders_payment_status'
  end

  def backfill_orders
    execute <<~SQL.squish
      INSERT INTO ibsoft_external_message_orders
        (account_id, inbox_id, opening_delivery_id, reference_id, order_status, created_at, updated_at)
      SELECT DISTINCT ON (account_id, inbox_id, order_reference_id)
        account_id,
        inbox_id,
        id,
        order_reference_id,
        'pending',
        created_at,
        updated_at
      FROM ibsoft_external_message_deliveries
      WHERE template_type = 'order'
        AND order_reference_id IS NOT NULL
      ORDER BY account_id, inbox_id, order_reference_id, created_at, id
    SQL
  end

  def create_order_updates
    create_table :ibsoft_external_message_order_updates do |t|
      add_order_update_references(t)
      add_order_update_request_fields(t)
      add_order_update_result_fields(t)
      add_order_update_timestamps(t)
      t.timestamps
    end

    add_order_update_indexes
    add_order_update_constraints
  end

  def add_order_update_references(table)
    table.references :order,
                     null: false,
                     foreign_key: { to_table: :ibsoft_external_message_orders },
                     index: { name: 'idx_ibsoft_ext_order_updates_order' }
    table.references :endpoint,
                     null: false,
                     foreign_key: { to_table: :ibsoft_external_message_endpoints },
                     index: { name: 'idx_ibsoft_ext_order_updates_endpoint' }
    table.references :account, null: false, foreign_key: true
    table.references :inbox, null: false, foreign_key: true
  end

  def add_order_update_request_fields(table)
    table.string :order_status
    table.string :payment_status
    table.text :message_content, null: false
    table.string :description
    table.bigint :payment_timestamp
  end

  def add_order_update_result_fields(table)
    table.string :status, null: false, default: 'queued'
    table.string :meta_message_id
    table.integer :meta_http_status
    table.string :error_code
    table.text :error_message
    table.integer :attempts_count, null: false, default: 0
  end

  def add_order_update_timestamps(table)
    table.datetime :received_at, null: false
    table.datetime :enqueued_at
    table.datetime :processing_started_at
    table.datetime :accepted_at
    table.datetime :delivered_at
    table.datetime :read_at
    table.datetime :failed_at
  end

  def add_order_update_indexes
    add_index :ibsoft_external_message_order_updates,
              [:order_id, :status, :id],
              name: 'idx_ibsoft_ext_order_updates_queue'
    add_index :ibsoft_external_message_order_updates,
              [:account_id, :created_at],
              name: 'idx_ibsoft_ext_order_updates_account_created'
    add_index :ibsoft_external_message_order_updates,
              [:inbox_id, :meta_message_id],
              unique: true,
              where: 'meta_message_id IS NOT NULL',
              name: 'idx_ibsoft_ext_order_updates_meta_message'
    add_index :ibsoft_external_message_order_updates,
              [:status, :enqueued_at],
              name: 'idx_ibsoft_ext_order_updates_dispatch'
  end

  def add_order_update_constraints
    add_check_constraint :ibsoft_external_message_order_updates,
                         "status IN ('queued', 'processing', 'accepted', 'sent', 'delivered', " \
                         "'read', 'failed', 'uncertain', 'unchanged')",
                         name: 'chk_ibsoft_ext_order_updates_status'
    add_check_constraint :ibsoft_external_message_order_updates,
                         'order_status IS NOT NULL OR payment_status IS NOT NULL',
                         name: 'chk_ibsoft_ext_order_updates_requested_status'
    add_check_constraint :ibsoft_external_message_order_updates,
                         "order_status IS NULL OR order_status IN ('pending', 'processing', " \
                         "'partially_shipped', 'shipped', 'completed', 'canceled')",
                         name: 'chk_ibsoft_ext_order_updates_order_status'
    add_check_constraint :ibsoft_external_message_order_updates,
                         "payment_status IS NULL OR payment_status IN ('pending', 'captured', 'failed')",
                         name: 'chk_ibsoft_ext_order_updates_payment_status'
    add_check_constraint :ibsoft_external_message_order_updates,
                         'payment_timestamp IS NULL OR payment_timestamp > 0',
                         name: 'chk_ibsoft_ext_order_updates_payment_timestamp'
  end
end

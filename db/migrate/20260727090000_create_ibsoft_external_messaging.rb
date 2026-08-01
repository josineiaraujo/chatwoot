class CreateIbsoftExternalMessaging < ActiveRecord::Migration[7.1]
  def change
    create_endpoints
    create_deliveries
  end

  private

  def create_endpoints
    create_table :ibsoft_external_message_endpoints do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_hint, null: false
      t.boolean :active, null: false, default: true
      t.integer :rate_limit_per_second, null: false, default: 10
      t.timestamps
    end

    add_index :ibsoft_external_message_endpoints,
              :token_digest,
              unique: true,
              name: 'idx_ibsoft_external_endpoints_token'
    add_index :ibsoft_external_message_endpoints,
              [:account_id, :name],
              unique: true,
              name: 'idx_ibsoft_external_endpoints_account_name'
  end

  def create_deliveries
    create_table :ibsoft_external_message_deliveries do |t|
      add_delivery_references(t)
      add_delivery_request_fields(t)
      add_delivery_result_fields(t)
      add_delivery_timestamps(t)
      t.timestamps
    end

    add_delivery_indexes
  end

  def add_delivery_references(table)
    table.references :endpoint,
                     null: false,
                     foreign_key: { to_table: :ibsoft_external_message_endpoints },
                     index: { name: 'idx_ibsoft_external_deliveries_endpoint' }
    table.references :account, null: false, foreign_key: true
    table.references :inbox, null: false, foreign_key: true
  end

  def add_delivery_request_fields(table)
    table.string :idempotency_key, null: false
    table.string :request_fingerprint, null: false
    table.string :recipient, null: false
    table.string :template_name, null: false
    table.string :template_language, null: false
    table.string :template_type, null: false, default: 'standard'
    table.jsonb :template_components, null: false, default: []
    table.text :message_content, null: false
    table.string :order_reference_id
  end

  def add_delivery_result_fields(table)
    table.string :status, null: false, default: 'queued'
    table.string :meta_message_id
    table.integer :meta_http_status
    table.string :error_code
    table.text :error_message
    table.integer :attempts_count, null: false, default: 0
  end

  def add_delivery_timestamps(table)
    table.datetime :received_at, null: false
    table.datetime :enqueued_at
    table.datetime :processing_started_at
    table.datetime :accepted_at
    table.datetime :delivered_at
    table.datetime :read_at
    table.datetime :failed_at
  end

  def add_delivery_indexes
    add_index :ibsoft_external_message_deliveries,
              [:endpoint_id, :idempotency_key],
              unique: true,
              name: 'idx_ibsoft_external_deliveries_idempotency'
    add_index :ibsoft_external_message_deliveries,
              [:account_id, :created_at],
              name: 'idx_ibsoft_external_deliveries_account_created'
    add_index :ibsoft_external_message_deliveries,
              [:inbox_id, :meta_message_id],
              unique: true,
              where: 'meta_message_id IS NOT NULL',
              name: 'idx_ibsoft_external_deliveries_meta_message'
    add_index :ibsoft_external_message_deliveries,
              [:status, :enqueued_at],
              name: 'idx_ibsoft_external_deliveries_dispatch'
  end
end

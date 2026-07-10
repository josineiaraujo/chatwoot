class CreateIbsoftMessageBroadcast < ActiveRecord::Migration[7.1]
  def change
    create_groups
    create_group_members
    create_broadcasts
    create_recipients
  end

  private

  def create_groups
    create_table :ibsoft_message_broadcast_groups do |t|
      t.references :account, null: false, index: true, foreign_key: true
      t.references :created_by, null: false, index: true, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :erp_provider, null: false
      t.text :description

      t.timestamps
    end

    add_index :ibsoft_message_broadcast_groups,
              [:account_id, :name],
              unique: true,
              name: 'idx_ibsoft_broadcast_groups_account_name'
  end

  def create_group_members
    create_table :ibsoft_message_broadcast_group_members do |t|
      t.references :group,
                   null: false,
                   index: true,
                   foreign_key: { to_table: :ibsoft_message_broadcast_groups }
      t.string :external_customer_id, null: false
      t.string :customer_name, null: false
      t.string :primary_phone
      t.string :fallback_phone
      t.string :city
      t.string :state
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :ibsoft_message_broadcast_group_members,
              [:group_id, :external_customer_id],
              unique: true,
              name: 'idx_ibsoft_broadcast_group_members_customer'
  end

  def create_broadcasts
    create_table :ibsoft_message_broadcasts do |t|
      add_broadcast_references(t)
      add_broadcast_columns(t)
      t.timestamps
    end

    add_index :ibsoft_message_broadcasts,
              [:account_id, :created_at],
              name: 'idx_ibsoft_broadcasts_account_created'
  end

  def create_recipients
    create_table :ibsoft_message_broadcast_recipients do |t|
      add_recipient_references(t)
      add_recipient_columns(t)
      t.timestamps
    end

    add_index :ibsoft_message_broadcast_recipients,
              [:broadcast_id, :external_customer_id],
              unique: true,
              name: 'idx_ibsoft_broadcast_recipients_customer'
  end

  def add_broadcast_references(table)
    table.references :account, null: false, index: true, foreign_key: true
    table.references :inbox, null: false, index: true, foreign_key: true
    table.references :erp_connection, null: false, index: true, foreign_key: { to_table: :ibsoft_erp_connections }
    table.references :created_by, null: false, index: true, foreign_key: { to_table: :users }
    table.references :assignee, index: true, foreign_key: { to_table: :users }
    table.references :team, index: true, foreign_key: true
  end

  def add_broadcast_columns(table)
    table.string :status, null: false, default: 'draft'
    table.string :source_type, null: false
    table.string :template_name, null: false
    table.string :template_language, null: false
    table.string :conversation_mode, null: false, default: 'close_after_send'
    table.jsonb :template_variables, null: false, default: {}
    table.datetime :started_at
    table.datetime :finished_at
  end

  def add_recipient_references(table)
    table.references :broadcast, null: false, index: true, foreign_key: { to_table: :ibsoft_message_broadcasts }
    table.references :conversation, index: true, foreign_key: true
    table.references :message, index: true, foreign_key: true
  end

  def add_recipient_columns(table)
    table.string :external_customer_id, null: false
    table.string :customer_name, null: false
    table.string :primary_phone
    table.string :fallback_phone
    table.string :phone_used
    table.string :phone_status, null: false, default: 'pending'
    table.string :status, null: false, default: 'pending'
    table.string :error_code
    table.text :error_message
  end
end

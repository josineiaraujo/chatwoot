class AddDeliveryModesToIbsoftMessageBroadcast < ActiveRecord::Migration[7.1]
  def change
    add_broadcast_delivery_columns
    add_recipient_delivery_columns
    add_delivery_indexes
  end

  private

  def add_broadcast_delivery_columns
    add_column :ibsoft_message_broadcasts,
               :dispatch_mode,
               :string,
               null: false,
               default: 'bulk'
    change_column_default :ibsoft_message_broadcasts,
                          :conversation_mode,
                          from: 'close_after_send',
                          to: 'direct'
  end

  def add_recipient_delivery_columns
    add_column :ibsoft_message_broadcast_recipients, :meta_message_id, :string
    add_column :ibsoft_message_broadcast_recipients, :enqueued_at, :datetime
    add_column :ibsoft_message_broadcast_recipients, :processing_started_at, :datetime
  end

  def add_delivery_indexes
    add_index :ibsoft_message_broadcast_recipients,
              :meta_message_id,
              unique: true,
              where: 'meta_message_id IS NOT NULL',
              name: 'idx_ibsoft_broadcast_recipients_meta_message'
    add_index :ibsoft_message_broadcast_recipients,
              [:status, :enqueued_at],
              name: 'idx_ibsoft_broadcast_recipients_dispatch'
    add_index :ibsoft_message_broadcasts,
              [:status, :updated_at],
              name: 'idx_ibsoft_broadcasts_dispatch'
  end
end

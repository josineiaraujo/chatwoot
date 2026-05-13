class CreateIbsoftInternalChat < ActiveRecord::Migration[7.1]
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def change
    create_table :ibsoft_internal_chat_rooms do |t|
      t.references :account, null: false, index: true
      t.references :created_by, null: false, index: true
      t.integer :room_type, null: false, default: 0
      t.string :name
      t.string :direct_key

      t.timestamps
    end

    add_index :ibsoft_internal_chat_rooms, [:account_id, :room_type]
    add_index :ibsoft_internal_chat_rooms, [:account_id, :direct_key], unique: true, where: 'direct_key IS NOT NULL'

    create_table :ibsoft_internal_chat_memberships do |t|
      t.references :account, null: false, index: true
      t.references :room, null: false, index: true
      t.references :user, null: false, index: true
      t.references :last_read_message, index: true
      t.integer :role, null: false, default: 0
      t.datetime :last_read_at

      t.timestamps
    end

    add_index :ibsoft_internal_chat_memberships,
              [:room_id, :user_id],
              unique: true,
              name: 'idx_ibsoft_chat_memberships_room_user'
    add_index :ibsoft_internal_chat_memberships, [:user_id, :room_id], name: 'idx_ibsoft_chat_memberships_user_room'

    create_table :ibsoft_internal_chat_messages do |t|
      t.references :account, null: false, index: true
      t.references :room, null: false, index: true
      t.references :sender, null: false, index: true
      t.integer :message_type, null: false, default: 0
      t.text :content
      t.jsonb :metadata, null: false, default: {}
      t.datetime :edited_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :ibsoft_internal_chat_messages, [:room_id, :created_at], name: 'idx_ibsoft_chat_messages_room_created'
    add_index :ibsoft_internal_chat_messages, [:account_id, :created_at], name: 'idx_ibsoft_chat_messages_account_created'

    create_table :ibsoft_internal_chat_attachments do |t|
      t.references :account, null: false, index: true
      t.references :message, null: false, index: true
      t.integer :file_type, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end

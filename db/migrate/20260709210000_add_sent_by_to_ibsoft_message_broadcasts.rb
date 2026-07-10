class AddSentByToIbsoftMessageBroadcasts < ActiveRecord::Migration[7.1]
  def change
    add_reference :ibsoft_message_broadcasts,
                  :sent_by,
                  index: true,
                  foreign_key: { to_table: :users }
  end
end

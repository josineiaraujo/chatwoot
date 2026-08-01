class AddOrderUpdateMessagesToIbsoftExternalMessaging < ActiveRecord::Migration[7.1]
  def change
    add_column :ibsoft_external_message_endpoints,
               :order_update_messages,
               :jsonb,
               null: false,
               default: {}

    add_check_constraint :ibsoft_external_message_endpoints,
                         "jsonb_typeof(order_update_messages) = 'object'",
                         name: 'chk_ibsoft_ext_endpoints_order_update_messages'
  end
end

class AddOrderPixDefaultsToIbsoftExternalMessaging < ActiveRecord::Migration[7.1]
  def change
    change_table :ibsoft_external_message_endpoints, bulk: true do |table|
      table.string :order_pix_merchant_name
      table.text :order_pix_key
      table.string :order_pix_key_type
    end

    add_column :ibsoft_external_message_deliveries, :order_pix_key, :text
  end
end

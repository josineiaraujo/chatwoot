class AddTemplateDeliveryToIbsoftExternalMessageOrderUpdates < ActiveRecord::Migration[7.1]
  def change
    add_endpoint_configuration
    add_order_update_snapshot
  end

  private

  def add_endpoint_configuration
    add_column :ibsoft_external_message_endpoints,
               :order_update_delivery_mode,
               :string,
               default: 'interactive',
               null: false
    add_column :ibsoft_external_message_endpoints,
               :order_update_template_settings,
               :jsonb,
               default: {},
               null: false

    add_check_constraint :ibsoft_external_message_endpoints,
                         "order_update_delivery_mode IN ('interactive', 'template')",
                         name: 'chk_ibsoft_ext_endpoints_update_delivery_mode'
    add_check_constraint :ibsoft_external_message_endpoints,
                         "jsonb_typeof(order_update_template_settings) = 'object'",
                         name: 'chk_ibsoft_ext_endpoints_update_template_settings'
  end

  def add_order_update_snapshot
    add_column :ibsoft_external_message_order_updates,
               :delivery_method,
               :string,
               default: 'interactive',
               null: false
    add_column :ibsoft_external_message_order_updates, :template_name, :string
    add_column :ibsoft_external_message_order_updates, :template_language, :string
    add_column :ibsoft_external_message_order_updates,
               :template_components,
               :jsonb,
               default: [],
               null: false

    add_check_constraint :ibsoft_external_message_order_updates,
                         "delivery_method IN ('interactive', 'template')",
                         name: 'chk_ibsoft_ext_order_updates_delivery_method'
    add_check_constraint :ibsoft_external_message_order_updates,
                         "jsonb_typeof(template_components) = 'array'",
                         name: 'chk_ibsoft_ext_order_updates_template_components'
  end
end

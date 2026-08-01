class AddInstanceTypeToIbsoftExternalMessageEndpoints < ActiveRecord::Migration[7.1]
  def change
    add_column :ibsoft_external_message_endpoints,
               :instance_type,
               :string,
               null: false,
               default: 'sgp_generic'
  end
end

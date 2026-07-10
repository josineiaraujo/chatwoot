class AddTemplateVariableValuesToIbsoftMessageBroadcastRecipients < ActiveRecord::Migration[7.1]
  def change
    add_column :ibsoft_message_broadcast_recipients,
               :template_variable_values,
               :jsonb,
               null: false,
               default: {}
  end
end

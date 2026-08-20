class AddFailureDiagnosticsToIbsoftExternalMessageEndpoints < ActiveRecord::Migration[7.1]
  def change
    add_column :ibsoft_external_message_endpoints,
               :failure_diagnostics_enabled,
               :boolean,
               null: false,
               default: false
  end
end

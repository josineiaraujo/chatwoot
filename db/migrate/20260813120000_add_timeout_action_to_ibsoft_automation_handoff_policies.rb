class AddTimeoutActionToIbsoftAutomationHandoffPolicies < ActiveRecord::Migration[7.1]
  def change
    add_column :ibsoft_conversation_distribution_automation_handoff_policies,
               :timeout_action,
               :string,
               null: false,
               default: 'forward_to_team'
  end
end

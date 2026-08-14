class AddExpectedRoutingToIbsoftAutomationCloseSchedules < ActiveRecord::Migration[7.1]
  TABLE_NAME = :ibsoft_conversation_distribution_automation_close_schedules

  def change
    add_column TABLE_NAME, :expected_team_id, :bigint
    add_column TABLE_NAME, :expected_agent_bot_id, :bigint
    add_column TABLE_NAME, :expected_policy_updated_at, :datetime, precision: 6
  end
end

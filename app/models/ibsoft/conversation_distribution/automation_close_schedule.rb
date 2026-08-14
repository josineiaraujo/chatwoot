# == Schema Information
#
# Table name: ibsoft_conversation_distribution_automation_close_schedules
#
#  id                           :bigint           not null, primary key
#  close_at                     :datetime         not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  account_id                   :bigint           not null
#  automation_handoff_policy_id :bigint           not null
#  conversation_id              :bigint           not null
#  expected_agent_bot_id        :bigint
#  expected_policy_updated_at   :datetime
#  expected_team_id             :bigint
#  trigger_message_id           :bigint           not null
#  warning_message_id           :bigint           not null
#
# Indexes
#
#  idx_ibsoft_auto_close_schedule_conversation  (conversation_id) UNIQUE
#  idx_ibsoft_auto_close_schedule_due           (account_id,close_at)
#  idx_ibsoft_auto_close_schedule_policy        (automation_handoff_policy_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (automation_handoff_policy_id => ibsoft_conversation_distribution_automation_handoff_policies.id) ON DELETE => cascade
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => cascade
#
class Ibsoft::ConversationDistribution::AutomationCloseSchedule < ApplicationRecord
  self.table_name = 'ibsoft_conversation_distribution_automation_close_schedules'

  belongs_to :account, class_name: '::Account'
  belongs_to :conversation, class_name: '::Conversation'
  belongs_to :automation_handoff_policy,
             class_name: 'Ibsoft::ConversationDistribution::AutomationHandoffPolicy'

  validates :conversation_id, uniqueness: true
  validates :trigger_message_id, :warning_message_id, :close_at, :expected_policy_updated_at, presence: true
  validate :resources_belong_to_account

  scope :due, -> { where(close_at: ..Time.current) }

  private

  def resources_belong_to_account
    return if account_id.blank?

    errors.add(:conversation, 'must belong to account') if conversation&.account_id != account_id
    return if automation_handoff_policy&.account_id == account_id

    errors.add(:automation_handoff_policy, 'must belong to account')
  end
end

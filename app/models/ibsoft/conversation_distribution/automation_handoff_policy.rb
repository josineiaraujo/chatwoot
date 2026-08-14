# == Schema Information
#
# Table name: ibsoft_conversation_distribution_automation_handoff_policies
#
#  id                          :bigint           not null, primary key
#  close_final_message         :text
#  close_final_message_enabled :boolean          default(FALSE), not null
#  close_warning_delay_minutes :integer          default(1), not null
#  close_warning_enabled       :boolean          default(FALSE), not null
#  close_warning_message       :text
#  customer_message            :text
#  customer_message_enabled    :boolean          default(FALSE), not null
#  enabled                     :boolean          default(FALSE), not null
#  stale_after_minutes         :integer          default(10), not null
#  timeout_action              :string           default("forward_to_team"), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  account_id                  :bigint           not null
#  inbox_id                    :bigint           not null
#  target_team_id              :bigint
#
# Indexes
#
#  idx_ibsoft_automation_handoff_account_enabled  (account_id,enabled)
#  idx_ibsoft_automation_handoff_account_inbox    (account_id,inbox_id) UNIQUE
#  idx_on_account_id_bda58423ea                   (account_id)
#  idx_on_inbox_id_e5240f4318                     (inbox_id)
#  idx_on_target_team_id_2133056d62               (target_team_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (target_team_id => teams.id)
#
class Ibsoft::ConversationDistribution::AutomationHandoffPolicy < ApplicationRecord
  self.table_name = 'ibsoft_conversation_distribution_automation_handoff_policies'

  DEFAULT_STALE_AFTER_MINUTES = 10
  MAX_STALE_AFTER_MINUTES = 7.days.to_i / 60
  DEFAULT_CLOSE_WARNING_DELAY_MINUTES = 1
  MAX_CLOSE_WARNING_DELAY_MINUTES = 1.day.to_i / 60
  ACTION_FORWARD_TO_TEAM = 'forward_to_team'.freeze
  ACTION_CLOSE_CONVERSATION = 'close_conversation'.freeze
  TIMEOUT_ACTIONS = [ACTION_FORWARD_TO_TEAM, ACTION_CLOSE_CONVERSATION].freeze

  belongs_to :account
  belongs_to :inbox
  belongs_to :target_team, class_name: 'Team', optional: true
  has_many :automation_close_schedules,
           class_name: 'Ibsoft::ConversationDistribution::AutomationCloseSchedule',
           dependent: :delete_all

  before_validation :normalize_defaults

  validates :inbox_id, uniqueness: { scope: :account_id }
  validates :stale_after_minutes,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: MAX_STALE_AFTER_MINUTES
            }
  validates :timeout_action, inclusion: { in: TIMEOUT_ACTIONS }
  validates :close_warning_delay_minutes,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: MAX_CLOSE_WARNING_DELAY_MINUTES
            }
  validates :target_team, presence: true, if: :target_team_required?
  validate :inbox_belongs_to_account
  validate :target_team_belongs_to_account

  scope :enabled, -> { where(enabled: true) }

  def forward_to_team?
    timeout_action == ACTION_FORWARD_TO_TEAM
  end

  def close_conversation?
    timeout_action == ACTION_CLOSE_CONVERSATION
  end

  def payload
    {
      id: id,
      account_id: account_id,
      inbox_id: inbox_id,
      enabled: enabled?,
      stale_after_minutes: stale_after_minutes,
      timeout_action: timeout_action,
      target_team_id: target_team_id,
      target_team_name: target_team&.name,
      customer_message_enabled: customer_message_enabled?,
      customer_message: customer_message.to_s,
      close_warning_enabled: close_warning_enabled?,
      close_warning_message: close_warning_message.to_s,
      close_warning_delay_minutes: close_warning_delay_minutes,
      close_final_message_enabled: close_final_message_enabled?,
      close_final_message: close_final_message.to_s,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def normalize_defaults
    normalize_timing_defaults
    normalize_action_defaults
    normalize_message_defaults
  end

  def normalize_timing_defaults
    self.stale_after_minutes = DEFAULT_STALE_AFTER_MINUTES unless stale_after_minutes.to_i.positive?
    self.close_warning_delay_minutes = DEFAULT_CLOSE_WARNING_DELAY_MINUTES if close_warning_delay_minutes.blank?
  end

  def normalize_action_defaults
    self.timeout_action = ACTION_FORWARD_TO_TEAM if timeout_action.blank?
    self.target_team = nil if timeout_action == ACTION_CLOSE_CONVERSATION
  end

  def normalize_message_defaults
    self.customer_message = customer_message.to_s.strip.presence
    self.close_warning_message = close_warning_message.to_s.strip.presence
    self.close_final_message = close_final_message.to_s.strip.presence
  end

  def target_team_required?
    enabled? && forward_to_team?
  end

  def inbox_belongs_to_account
    return if inbox.blank? || account_id.blank?
    return if inbox.account_id == account_id

    errors.add(:inbox, 'must belong to account')
  end

  def target_team_belongs_to_account
    return if target_team.blank? || account_id.blank?
    return if target_team.account_id == account_id

    errors.add(:target_team, 'must belong to account')
  end
end

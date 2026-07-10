# == Schema Information
#
# Table name: ibsoft_conversation_distribution_automation_handoff_policies
#
#  id                       :bigint           not null, primary key
#  customer_message         :text
#  customer_message_enabled :boolean          default(FALSE), not null
#  enabled                  :boolean          default(FALSE), not null
#  stale_after_minutes      :integer          default(10), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint           not null
#  inbox_id                 :bigint           not null
#  target_team_id           :bigint
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

  belongs_to :account
  belongs_to :inbox
  belongs_to :target_team, class_name: 'Team', optional: true

  before_validation :normalize_defaults

  validates :inbox_id, uniqueness: { scope: :account_id }
  validates :stale_after_minutes,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: MAX_STALE_AFTER_MINUTES
            }
  validates :target_team, presence: true, if: :enabled?
  validate :inbox_belongs_to_account
  validate :target_team_belongs_to_account

  scope :enabled, -> { where(enabled: true) }

  def payload
    {
      id: id,
      account_id: account_id,
      inbox_id: inbox_id,
      enabled: enabled?,
      stale_after_minutes: stale_after_minutes,
      target_team_id: target_team_id,
      target_team_name: target_team&.name,
      customer_message_enabled: customer_message_enabled?,
      customer_message: customer_message.to_s,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def normalize_defaults
    self.stale_after_minutes = DEFAULT_STALE_AFTER_MINUTES unless stale_after_minutes.to_i.positive?
    self.customer_message = customer_message.to_s.strip.presence
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

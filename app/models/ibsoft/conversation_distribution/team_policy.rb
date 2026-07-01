class Ibsoft::ConversationDistribution::TeamPolicy < ApplicationRecord
  self.table_name = 'ibsoft_conversation_distribution_team_policies'

  include Ibsoft::ConversationDistribution::Configuration

  belongs_to :account
  belongs_to :team
  belongs_to :inbox, optional: true

  validates :team_id, uniqueness: { scope: [:account_id, :inbox_id] }
  validate :team_belongs_to_account
  validate :inbox_belongs_to_account

  scope :global_for_team, -> { where(inbox_id: nil) }
  scope :for_inbox, ->(inbox) { where(inbox_id: inbox.id) }

  def payload
    super.merge(
      team_id: team_id,
      inbox_id: inbox_id,
      override_channel_policy: override_channel_policy?,
      policy_type: 'team'
    )
  end

  private

  def team_belongs_to_account
    return if team.blank? || account_id.blank?
    return if team.account_id == account_id

    errors.add(:team, 'must belong to account')
  end

  def inbox_belongs_to_account
    return if inbox.blank? || account_id.blank?
    return if inbox.account_id == account_id

    errors.add(:inbox, 'must belong to account')
  end
end

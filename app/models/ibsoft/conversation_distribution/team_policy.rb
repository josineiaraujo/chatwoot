# == Schema Information
#
# Table name: ibsoft_conversation_distribution_team_policies
#
#  id                      :bigint           not null, primary key
#  override_channel_policy :boolean          default(FALSE), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :bigint           not null
#  distribution_policy_id  :bigint
#  inbox_id                :bigint
#  team_id                 :bigint           not null
#
# Indexes
#
#  idx_ibsoft_distribution_team_inbox_policy   (account_id,team_id,inbox_id) UNIQUE WHERE (inbox_id IS NOT NULL)
#  idx_ibsoft_distribution_team_policy         (account_id,team_id) UNIQUE WHERE (inbox_id IS NULL)
#  idx_ibsoft_team_policy_distribution_policy  (distribution_policy_id)
#  idx_on_account_id_1409f9bfca                (account_id)
#  idx_on_inbox_id_6f03247c22                  (inbox_id)
#  idx_on_team_id_d59e9eeb35                   (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (distribution_policy_id => ibsoft_conversation_distribution_policies.id)
#
class Ibsoft::ConversationDistribution::TeamPolicy < ApplicationRecord
  self.table_name = 'ibsoft_conversation_distribution_team_policies'

  belongs_to :account
  belongs_to :team
  belongs_to :inbox, optional: true
  belongs_to :distribution_policy,
             class_name: 'Ibsoft::ConversationDistribution::Policy',
             inverse_of: :team_policies,
             optional: true

  validates :team_id, uniqueness: { scope: [:account_id, :inbox_id] }
  validate :team_belongs_to_account
  validate :inbox_belongs_to_account
  validate :distribution_policy_belongs_to_account

  scope :global_for_team, -> { where(inbox_id: nil) }
  scope :for_inbox, ->(inbox) { where(inbox_id: inbox.id) }

  def payload
    base_payload.merge(
      team_id: team_id,
      inbox_id: inbox_id,
      override_channel_policy: override_channel_policy?,
      policy_type: 'team',
      native_assignment: native_assignment_payload
    )
  end

  private

  def base_payload
    policy = distribution_policy

    {
      id: id,
      account_id: account_id,
      enabled: policy ? policy.enabled? : false,
      config: policy ? policy.effective_config : Ibsoft::ConversationDistribution::Policy.default_config,
      distribution_policy_id: policy&.id,
      distribution_policy_name: policy&.name,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def native_assignment_payload
    {
      team_auto_assignment_enabled: team.allow_auto_assign?
    }
  end

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

  def distribution_policy_belongs_to_account
    return if distribution_policy.blank? || account_id.blank?
    return if distribution_policy.account_id == account_id

    errors.add(:distribution_policy, 'must belong to account')
  end
end

# == Schema Information
#
# Table name: ibsoft_conversation_distribution_channel_policies
#
#  id                     :bigint           not null, primary key
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  distribution_policy_id :bigint
#  inbox_id               :bigint           not null
#
# Indexes
#
#  idx_ibsoft_channel_policy_distribution_policy  (distribution_policy_id)
#  idx_ibsoft_distribution_channel_policy         (account_id,inbox_id) UNIQUE
#  idx_on_account_id_ead7529b02                   (account_id)
#  idx_on_inbox_id_54ce8caae9                     (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (distribution_policy_id => ibsoft_conversation_distribution_policies.id)
#
class Ibsoft::ConversationDistribution::ChannelPolicy < ApplicationRecord
  self.table_name = 'ibsoft_conversation_distribution_channel_policies'

  belongs_to :account
  belongs_to :inbox
  belongs_to :distribution_policy,
             class_name: 'Ibsoft::ConversationDistribution::Policy',
             inverse_of: :channel_policies,
             optional: true

  validates :inbox_id, uniqueness: { scope: :account_id }
  validate :inbox_belongs_to_account
  validate :distribution_policy_belongs_to_account

  def payload
    base_payload.merge(
      inbox_id: inbox_id,
      policy_type: 'channel',
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
      inbox_auto_assignment_enabled: inbox.enable_auto_assignment?,
      assignment_policy_id: inbox.assignment_policy&.id
    }
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

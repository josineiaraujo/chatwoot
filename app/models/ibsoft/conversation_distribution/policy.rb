# == Schema Information
#
# Table name: ibsoft_conversation_distribution_policies
#
#  id                    :bigint           not null, primary key
#  config                :jsonb            not null
#  enabled               :boolean          default(FALSE), not null
#  name                  :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  after_hours_policy_id :bigint
#
# Indexes
#
#  idx_ibsoft_distribution_policies_account       (account_id)
#  idx_ibsoft_distribution_policies_account_name  (account_id,name) UNIQUE
#  idx_ibsoft_distribution_policies_after_hours   (after_hours_policy_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (after_hours_policy_id => ibsoft_after_hours_policies.id) ON DELETE => nullify
#
class Ibsoft::ConversationDistribution::Policy < ApplicationRecord
  self.table_name = 'ibsoft_conversation_distribution_policies'

  include Ibsoft::ConversationDistribution::Configuration

  belongs_to :account
  belongs_to :after_hours_policy,
             class_name: 'Ibsoft::AfterHours::Policy',
             inverse_of: :distribution_policies,
             optional: true
  has_many :channel_policies,
           class_name: 'Ibsoft::ConversationDistribution::ChannelPolicy',
           foreign_key: :distribution_policy_id,
           inverse_of: :distribution_policy,
           dependent: :nullify
  has_many :team_policies,
           class_name: 'Ibsoft::ConversationDistribution::TeamPolicy',
           foreign_key: :distribution_policy_id,
           inverse_of: :distribution_policy,
           dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validate :after_hours_policy_belongs_to_account

  def payload
    super.merge(
      name: name,
      linked_channels_count: channel_policies.count,
      linked_teams_count: team_policies.count,
      after_hours_policy_id: after_hours_policy_id,
      after_hours_policy_name: after_hours_policy&.name,
      policy_type: 'named'
    )
  end

  private

  def after_hours_policy_belongs_to_account
    return if after_hours_policy.blank? || after_hours_policy.account_id == account_id

    errors.add(:after_hours_policy, :invalid)
  end
end

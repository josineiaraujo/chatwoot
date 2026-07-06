# == Schema Information
#
# Table name: ibsoft_conversation_distribution_policies
#
#  id         :bigint           not null, primary key
#  config     :jsonb            not null
#  enabled    :boolean          default(FALSE), not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  idx_ibsoft_distribution_policies_account       (account_id)
#  idx_ibsoft_distribution_policies_account_name  (account_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Ibsoft::ConversationDistribution::Policy < ApplicationRecord
  self.table_name = 'ibsoft_conversation_distribution_policies'

  include Ibsoft::ConversationDistribution::Configuration

  belongs_to :account
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

  def payload
    super.merge(
      name: name,
      linked_channels_count: channel_policies.count,
      linked_teams_count: team_policies.count,
      policy_type: 'named'
    )
  end
end

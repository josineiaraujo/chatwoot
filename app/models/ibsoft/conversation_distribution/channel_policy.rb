# == Schema Information
#
# Table name: ibsoft_conversation_distribution_channel_policies
#
#  id         :bigint           not null, primary key
#  config     :jsonb            not null
#  enabled    :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  inbox_id   :bigint           not null
#
# Indexes
#
#  idx_ibsoft_distribution_channel_policy  (account_id,inbox_id) UNIQUE
#  idx_on_account_id_ead7529b02            (account_id)
#  idx_on_inbox_id_54ce8caae9              (inbox_id)
#
class Ibsoft::ConversationDistribution::ChannelPolicy < ApplicationRecord
  self.table_name = 'ibsoft_conversation_distribution_channel_policies'

  include Ibsoft::ConversationDistribution::Configuration

  belongs_to :account
  belongs_to :inbox

  validates :inbox_id, uniqueness: { scope: :account_id }
  validate :inbox_belongs_to_account

  def payload
    super.merge(inbox_id: inbox_id, policy_type: 'channel')
  end

  private

  def inbox_belongs_to_account
    return if inbox.blank? || account_id.blank?
    return if inbox.account_id == account_id

    errors.add(:inbox, 'must belong to account')
  end
end

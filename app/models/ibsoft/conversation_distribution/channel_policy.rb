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

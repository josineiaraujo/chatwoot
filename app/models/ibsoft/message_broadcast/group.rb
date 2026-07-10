# == Schema Information
#
# Table name: ibsoft_message_broadcast_groups
#
#  id            :bigint           not null, primary key
#  description   :text
#  erp_provider  :string           not null
#  name          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  created_by_id :bigint           not null
#
# Indexes
#
#  idx_ibsoft_broadcast_groups_account_name                (account_id,name) UNIQUE
#  index_ibsoft_message_broadcast_groups_on_account_id     (account_id)
#  index_ibsoft_message_broadcast_groups_on_created_by_id  (created_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (created_by_id => users.id)
#
class Ibsoft::MessageBroadcast::Group < ApplicationRecord
  self.table_name = 'ibsoft_message_broadcast_groups'

  belongs_to :account
  belongs_to :created_by, class_name: 'User'
  has_many :members,
           class_name: 'Ibsoft::MessageBroadcast::GroupMember',
           inverse_of: :group,
           dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :erp_provider, presence: true

  def payload
    {
      id: id,
      name: name,
      description: description,
      erp_provider: erp_provider,
      members_count: members.count,
      created_at: created_at,
      updated_at: updated_at
    }
  end
end

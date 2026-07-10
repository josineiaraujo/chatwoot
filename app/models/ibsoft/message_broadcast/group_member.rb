# == Schema Information
#
# Table name: ibsoft_message_broadcast_group_members
#
#  id                   :bigint           not null, primary key
#  active               :boolean          default(TRUE), not null
#  city                 :string
#  customer_name        :string           not null
#  fallback_phone       :string
#  primary_phone        :string
#  state                :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  external_customer_id :string           not null
#  group_id             :bigint           not null
#
# Indexes
#
#  idx_ibsoft_broadcast_group_members_customer               (group_id,external_customer_id) UNIQUE
#  index_ibsoft_message_broadcast_group_members_on_group_id  (group_id)
#
# Foreign Keys
#
#  fk_rails_...  (group_id => ibsoft_message_broadcast_groups.id)
#
class Ibsoft::MessageBroadcast::GroupMember < ApplicationRecord
  self.table_name = 'ibsoft_message_broadcast_group_members'

  belongs_to :group,
             class_name: 'Ibsoft::MessageBroadcast::Group',
             inverse_of: :members

  validates :external_customer_id, :customer_name, presence: true
  validates :external_customer_id, uniqueness: { scope: :group_id }

  def payload
    {
      id: id,
      external_customer_id: external_customer_id,
      customer_name: customer_name,
      primary_phone: primary_phone,
      fallback_phone: fallback_phone,
      city: city,
      state: state,
      active: active
    }
  end
end

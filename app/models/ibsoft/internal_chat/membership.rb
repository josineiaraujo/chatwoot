# == Schema Information
#
# Table name: ibsoft_internal_chat_memberships
#
#  id                   :bigint           not null, primary key
#  last_read_at         :datetime
#  role                 :integer          default("member"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  last_read_message_id :bigint
#  room_id              :bigint           not null
#  user_id              :bigint           not null
#
# Indexes
#
#  idx_ibsoft_chat_memberships_room_user                           (room_id,user_id) UNIQUE
#  idx_ibsoft_chat_memberships_user_room                           (user_id,room_id)
#  index_ibsoft_internal_chat_memberships_on_account_id            (account_id)
#  index_ibsoft_internal_chat_memberships_on_last_read_message_id  (last_read_message_id)
#  index_ibsoft_internal_chat_memberships_on_room_id               (room_id)
#  index_ibsoft_internal_chat_memberships_on_user_id               (user_id)
#
class Ibsoft::InternalChat::Membership < ApplicationRecord
  self.table_name = 'ibsoft_internal_chat_memberships'

  belongs_to :account
  belongs_to :room,
             class_name: 'Ibsoft::InternalChat::Room',
             inverse_of: :memberships
  belongs_to :user
  belongs_to :last_read_message,
             class_name: 'Ibsoft::InternalChat::Message',
             optional: true

  enum role: { member: 0, admin: 1 }

  validates :account, :room, :user, :role, presence: true
  validates :user_id, uniqueness: { scope: :room_id }
  validate :account_matches_room
  validate :user_belongs_to_account

  private

  def account_matches_room
    errors.add(:account, :invalid) if room.present? && account_id != room.account_id
  end

  def user_belongs_to_account
    return if account.blank? || user.blank?
    return if account.account_users.exists?(user_id: user.id)

    errors.add(:user, :invalid)
  end
end

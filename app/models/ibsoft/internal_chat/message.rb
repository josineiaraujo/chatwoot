# == Schema Information
#
# Table name: ibsoft_internal_chat_messages
#
#  id           :bigint           not null, primary key
#  content      :text
#  deleted_at   :datetime
#  edited_at    :datetime
#  message_type :integer          default("text"), not null
#  metadata     :jsonb            not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  room_id      :bigint           not null
#  sender_id    :bigint           not null
#
# Indexes
#
#  idx_ibsoft_chat_messages_account_created           (account_id,created_at)
#  idx_ibsoft_chat_messages_room_created              (room_id,created_at)
#  index_ibsoft_internal_chat_messages_on_account_id  (account_id)
#  index_ibsoft_internal_chat_messages_on_room_id     (room_id)
#  index_ibsoft_internal_chat_messages_on_sender_id   (sender_id)
#
class Ibsoft::InternalChat::Message < ApplicationRecord
  self.table_name = 'ibsoft_internal_chat_messages'

  belongs_to :account
  belongs_to :room,
             class_name: 'Ibsoft::InternalChat::Room',
             inverse_of: :messages
  belongs_to :sender, class_name: 'User'

  has_many :attachments,
           class_name: 'Ibsoft::InternalChat::Attachment',
           dependent: :destroy,
           inverse_of: :message

  enum message_type: { text: 0, activity: 1 }

  validates :account, :room, :sender, :message_type, presence: true
  validate :account_matches_room

  scope :visible, -> { where(deleted_at: nil) }

  def payload
    {
      id: id,
      room_id: room_id,
      message_type: message_type,
      content: content.to_s,
      sender: sender_payload,
      attachments: attachments.map(&:payload),
      created_at: created_at.iso8601,
      updated_at: updated_at.iso8601,
      edited_at: edited_at&.iso8601
    }
  end

  private

  def account_matches_room
    errors.add(:account, :invalid) if room.present? && account_id != room.account_id
  end

  def sender_payload
    avatar_url = sender.avatar_url

    {
      id: sender.id,
      name: sender.name,
      available_name: sender.available_name,
      avatar_url: avatar_url,
      thumbnail: avatar_url,
      availability_status: sender.availability_status
    }
  end
end

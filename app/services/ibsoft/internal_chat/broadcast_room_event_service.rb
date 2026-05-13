class Ibsoft::InternalChat::BroadcastRoomEventService
  ROOM_UPDATED_EVENT = 'ibsoft.internal_chat.room_updated'.freeze
  ROOM_DELETED_EVENT = 'ibsoft.internal_chat.room_deleted'.freeze
  MEMBER_REMOVED_EVENT = 'ibsoft.internal_chat.member_removed'.freeze

  def self.room_updated(room)
    room.reload.members.find_each do |member|
      next if member.pubsub_token.blank?

      ActionCableBroadcastJob.perform_later(
        [member.pubsub_token],
        ROOM_UPDATED_EVENT,
        {
          account_id: room.account_id,
          room: room.payload_for(member)
        }
      )
    end
  end

  def self.room_deleted(room, members:)
    broadcast_tokens(
      members,
      ROOM_DELETED_EVENT,
      {
        account_id: room.account_id,
        room_id: room.id
      }
    )
  end

  def self.member_removed(room, member:)
    broadcast_tokens(
      [member],
      MEMBER_REMOVED_EVENT,
      {
        account_id: room.account_id,
        room_id: room.id
      }
    )
  end

  def self.broadcast_tokens(users, event_name, payload)
    tokens = users.filter_map(&:pubsub_token)
    return if tokens.blank?

    ActionCableBroadcastJob.perform_later(tokens, event_name, payload)
  end
  private_class_method :broadcast_tokens
end

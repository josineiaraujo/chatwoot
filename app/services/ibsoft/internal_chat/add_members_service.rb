class Ibsoft::InternalChat::AddMembersService
  def initialize(room:)
    @room = room
  end

  def perform(user_ids:)
    raise Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.direct_room_immutable') if @room.direct?

    users = member_lookup.users_for(user_ids)
    users.each do |user|
      @room.memberships.find_or_create_by!(account: @room.account, user: user) do |membership|
        membership.role = :member
        membership.last_read_at = Time.current
      end
    end

    Ibsoft::InternalChat::BroadcastRoomEventService.room_updated(@room)
    @room
  end

  private

  def member_lookup
    @member_lookup ||= Ibsoft::InternalChat::MemberLookup.new(account: @room.account)
  end
end

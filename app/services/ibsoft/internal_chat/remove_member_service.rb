class Ibsoft::InternalChat::RemoveMemberService
  def initialize(room:, membership:)
    @room = room
    @membership = membership
  end

  def perform
    raise Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.direct_room_immutable') if @room.direct?
    raise Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.room_creator_cannot_be_removed') if room_creator?
    raise Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.last_room_member') if last_member?
    raise Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.last_room_admin') if last_admin?

    removed_user = @membership.user
    @membership.destroy!
    Ibsoft::InternalChat::BroadcastRoomEventService.member_removed(@room, member: removed_user)
    Ibsoft::InternalChat::BroadcastRoomEventService.room_updated(@room)
  end

  private

  def last_member?
    @room.memberships.where.not(id: @membership.id).none?
  end

  def room_creator?
    @membership.user_id == @room.created_by_id
  end

  def last_admin?
    return false unless @membership.admin?

    @room.memberships.admin.where.not(id: @membership.id).none?
  end
end

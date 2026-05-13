class Ibsoft::InternalChat::UpdateRoomService
  def initialize(room:, current_user:)
    @room = room
    @current_user = current_user
  end

  def perform(name: nil, cover_image: nil)
    raise Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.direct_room_immutable') if @room.direct?
    raise Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.not_room_member') unless room_member?

    assign_name(name)

    @room.cover_image.attach(cover_image) if cover_image.present?
    raise Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.room_name_required') if @room.name.blank?

    @room.save!
    Ibsoft::InternalChat::BroadcastRoomEventService.room_updated(@room)
    @room
  end

  private

  def assign_name(name)
    return if name.blank?

    next_name = name.to_s.strip
    return if next_name == @room.name

    raise Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.only_creator_can_rename_room') unless room_creator?

    @room.name = next_name
  end

  def room_member?
    @room.memberships.exists?(user_id: @current_user.id)
  end

  def room_creator?
    @room.created_by_id == @current_user.id
  end
end

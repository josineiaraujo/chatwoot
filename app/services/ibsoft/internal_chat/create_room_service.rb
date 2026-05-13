class Ibsoft::InternalChat::CreateRoomService
  def initialize(account:, current_user:)
    @account = account
    @current_user = current_user
  end

  def perform(name:, user_ids:)
    users = member_lookup.users_for(Array(user_ids) | [@current_user.id])
    raise Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.room_name_required') if name.blank?

    room = create_room(name: name, users: users)
    Ibsoft::InternalChat::BroadcastRoomEventService.room_updated(room)
    room
  end

  private

  def create_room(name:, users:)
    Ibsoft::InternalChat::Room.transaction do
      room = build_room(name)
      users.each { |user| create_membership(room, user) }
      room
    end
  end

  def build_room(name)
    Ibsoft::InternalChat::Room.create!(
      account: @account,
      created_by: @current_user,
      room_type: :room,
      name: name.to_s.strip
    )
  end

  def create_membership(room, user)
    room.memberships.create!(
      account: @account,
      user: user,
      role: user.id == @current_user.id ? :admin : :member,
      last_read_at: Time.current
    )
  end

  def member_lookup
    @member_lookup ||= Ibsoft::InternalChat::MemberLookup.new(account: @account)
  end
end

class Ibsoft::InternalChat::FindOrCreateDirectRoomService
  def initialize(account:, current_user:)
    @account = account
    @current_user = current_user
  end

  def perform(target_user_id:)
    target_user = member_lookup.users_for([target_user_id]).first
    raise Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.direct_self') if target_user.id == @current_user.id

    room = find_room(target_user.id)
    return room if room.present?

    create_room(target_user)
  rescue ActiveRecord::RecordNotUnique
    find_room(target_user.id)
  end

  private

  def create_room(target_user)
    Ibsoft::InternalChat::Room.transaction do
      room = Ibsoft::InternalChat::Room.create!(
        account: @account,
        created_by: @current_user,
        room_type: :direct,
        direct_key: direct_key(target_user.id)
      )

      [@current_user, target_user].each do |user|
        room.memberships.create!(
          account: @account,
          user: user,
          role: :member,
          last_read_at: Time.current
        )
      end

      room
    end
  end

  def find_room(target_user_id)
    Ibsoft::InternalChat::Room.find_by(
      account: @account,
      room_type: :direct,
      direct_key: direct_key(target_user_id)
    )
  end

  def direct_key(target_user_id)
    [@current_user.id, target_user_id.to_i].sort.join(':')
  end

  def member_lookup
    @member_lookup ||= Ibsoft::InternalChat::MemberLookup.new(account: @account)
  end
end

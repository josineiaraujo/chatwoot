class Api::V1::Accounts::Ibsoft::InternalChat::RoomsController < Api::V1::Accounts::Ibsoft::InternalChat::BaseController
  before_action :fetch_room, only: [:show, :update]
  before_action :fetch_account_room, only: [:destroy]

  def index
    authorize Ibsoft::InternalChat::Room

    rooms = rooms_scope
            .distinct(false)
            .left_joins(:messages)
            .select('ibsoft_internal_chat_rooms.*, MAX(ibsoft_internal_chat_messages.created_at) AS last_message_at')
            .group('ibsoft_internal_chat_rooms.id')
            .order(Arel.sql('last_message_at DESC NULLS LAST, ibsoft_internal_chat_rooms.updated_at DESC'))

    render json: rooms.map { |room| room.payload_for(current_user) }
  end

  def unread_count
    authorize Ibsoft::InternalChat::Room, :index?

    render json: unread_rooms_count
  end

  def show
    authorize @room
    render_room(@room)
  end

  def create
    authorize Ibsoft::InternalChat::Room

    room = Ibsoft::InternalChat::CreateRoomService.new(
      account: Current.account,
      current_user: current_user
    ).perform(name: room_params[:name], user_ids: room_params[:user_ids])

    render_room(room, status: :created)
  end

  def update
    authorize @room

    room = Ibsoft::InternalChat::UpdateRoomService.new(room: @room, current_user: current_user).perform(
      name: room_params[:name],
      cover_image: room_params[:cover_image]
    )
    render_room(room)
  end

  def destroy
    authorize @room

    members = @room.members.to_a
    Ibsoft::InternalChat::BroadcastRoomEventService.room_deleted(@room, members: members)
    @room.destroy!
    head :ok
  end

  def direct
    authorize Ibsoft::InternalChat::Room, :create?

    room = Ibsoft::InternalChat::FindOrCreateDirectRoomService.new(
      account: Current.account,
      current_user: current_user
    ).perform(target_user_id: params[:target_user_id])

    render_room(room, status: :created)
  end

  private

  def room_params
    params.permit(:name, :cover_image, user_ids: [])
  end

  def unread_rooms_count
    Ibsoft::InternalChat::Membership
      .joins(room: :messages)
      .where(
        account_id: Current.account.id,
        user_id: current_user.id,
        ibsoft_internal_chat_rooms: { account_id: Current.account.id },
        ibsoft_internal_chat_messages: { account_id: Current.account.id, deleted_at: nil }
      )
      .where.not(ibsoft_internal_chat_messages: { sender_id: current_user.id })
      .where(
        'ibsoft_internal_chat_memberships.last_read_at IS NULL OR ' \
        'ibsoft_internal_chat_messages.created_at > ibsoft_internal_chat_memberships.last_read_at'
      )
      .distinct
      .count(:room_id)
  end

  def fetch_account_room
    @room = Ibsoft::InternalChat::Room.where(account_id: Current.account.id).find(params[:id])
  end
end

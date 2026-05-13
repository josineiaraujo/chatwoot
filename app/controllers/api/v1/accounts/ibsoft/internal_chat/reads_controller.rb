class Api::V1::Accounts::Ibsoft::InternalChat::ReadsController < Api::V1::Accounts::Ibsoft::InternalChat::BaseController
  ACTIVE_ROOM_READ_CONTEXT = 'active_room'.freeze

  before_action :fetch_room

  def create
    authorize @room, :show?
    return head :no_content unless active_room_read_context?

    Ibsoft::InternalChat::MarkAsReadService.new(
      room: @room,
      current_user: current_user
    ).perform(message_id: params[:message_id])

    render_room(@room)
  end

  private

  def active_room_read_context?
    params[:read_context] == ACTIVE_ROOM_READ_CONTEXT &&
      params[:active_room_id].to_i == @room.id
  end
end

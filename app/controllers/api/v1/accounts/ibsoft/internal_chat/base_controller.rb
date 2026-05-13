class Api::V1::Accounts::Ibsoft::InternalChat::BaseController < Api::V1::Accounts::BaseController
  rescue_from Ibsoft::InternalChat::Error, with: :render_internal_chat_error

  private

  def rooms_scope
    policy_scope(Ibsoft::InternalChat::Room)
      .includes(
        cover_image_attachment: :blob,
        members: [:account_users, { avatar_attachment: :blob }],
        memberships: :user
      )
  end

  def fetch_room
    @room = rooms_scope.find(params[:room_id] || params[:id])
  end

  def render_room(room, status: :ok)
    render json: room.reload.payload_for(current_user), status: status
  end

  def render_internal_chat_error(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end
end

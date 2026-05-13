class Ibsoft::InternalChat::MarkAsReadService
  def initialize(room:, current_user:)
    @room = room
    @current_user = current_user
  end

  def perform(message_id: nil)
    membership = @room.memberships.find_by!(user_id: @current_user.id)
    message = message_id.present? ? @room.messages.find(message_id) : @room.messages.visible.order(created_at: :desc).first

    membership.update!(
      last_read_at: Time.current,
      last_read_message: message
    )

    membership
  end
end

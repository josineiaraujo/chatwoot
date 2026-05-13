class Api::V1::Accounts::Ibsoft::InternalChat::MembershipsController < Api::V1::Accounts::Ibsoft::InternalChat::BaseController
  before_action :fetch_room

  def create
    authorize @room, :manage_members?

    room = Ibsoft::InternalChat::AddMembersService.new(room: @room).perform(user_ids: params[:user_ids])
    render_room(room)
  end

  def destroy
    authorize @room, :manage_members?

    membership = @room.memberships.find(params[:id])
    Ibsoft::InternalChat::RemoveMemberService.new(room: @room, membership: membership).perform
    render_room(@room)
  end
end

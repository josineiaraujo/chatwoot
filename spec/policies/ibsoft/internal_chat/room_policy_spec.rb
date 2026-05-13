require 'rails_helper'

RSpec.describe Ibsoft::InternalChat::RoomPolicy, type: :policy do
  subject(:policy) { described_class }

  let!(:account) { create(:account) }
  let!(:creator) { create(:user, account: account) }
  let!(:member) { create(:user, account: account) }
  let!(:administrator) { create(:user, :administrator, account: account) }
  let!(:outsider) { create(:user, account: account) }
  let!(:room) do
    Ibsoft::InternalChat::CreateRoomService.new(
      account: account,
      current_user: creator
    ).perform(name: 'Operacoes', user_ids: [member.id])
  end
  let!(:direct_room) do
    Ibsoft::InternalChat::FindOrCreateDirectRoomService.new(
      account: account,
      current_user: creator
    ).perform(target_user_id: member.id)
  end

  let(:creator_context) { { user: creator, account: account, account_user: creator.current_account_user } }
  let(:member_context) { { user: member, account: account, account_user: member.current_account_user } }
  let(:administrator_context) { { user: administrator, account: account, account_user: administrator.current_account_user } }
  let(:outsider_context) { { user: outsider, account: account, account_user: outsider.current_account_user } }

  before do
    Current.account = account
  end

  after do
    Current.account = nil
  end

  permissions :create? do
    it 'allows account users to create rooms' do
      expect(policy).to permit(member_context, Ibsoft::InternalChat::Room)
    end
  end

  permissions :update? do
    it 'allows room participants to update room metadata' do
      expect(policy).to permit(creator_context, room)
      expect(policy).to permit(member_context, room)
    end

    it 'denies users outside the room' do
      expect(policy).not_to permit(outsider_context, room)
    end
  end

  permissions :manage_members? do
    it 'allows only the room creator to manage members' do
      expect(policy).to permit(creator_context, room)
      expect(policy).not_to permit(member_context, room)
      expect(policy).not_to permit(administrator_context, room)
    end
  end

  permissions :destroy? do
    it 'allows the room creator and account administrators to delete rooms' do
      expect(policy).to permit(creator_context, room)
      expect(policy).to permit(administrator_context, room)
      expect(policy).to permit(administrator_context, direct_room)
    end

    it 'denies regular room members' do
      expect(policy).not_to permit(member_context, room)
    end

    it 'denies direct chat participants who are not administrators' do
      expect(policy).not_to permit(member_context, direct_room)
    end
  end

  describe '#show?' do
    it 'does not allow account administrators to inspect chats they do not participate in' do
      expect(described_class.new(administrator_context, direct_room).show?).to be false
    end
  end

  permissions :show?, :post_message? do
    it 'denies a removed room member' do
      membership = room.memberships.find_by!(user: member)

      Ibsoft::InternalChat::RemoveMemberService.new(room: room, membership: membership).perform

      expect(policy).not_to permit(member_context, room)
    end
  end
end

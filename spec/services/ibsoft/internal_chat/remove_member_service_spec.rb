require 'rails_helper'

RSpec.describe Ibsoft::InternalChat::RemoveMemberService do
  let!(:account) { create(:account) }
  let!(:creator) { create(:user, account: account) }
  let!(:member) { create(:user, account: account) }
  let!(:room) do
    Ibsoft::InternalChat::CreateRoomService.new(
      account: account,
      current_user: creator
    ).perform(name: 'Operacoes', user_ids: [member.id])
  end

  describe '#perform' do
    it 'removes a regular member from the room' do
      membership = room.memberships.find_by!(user: member)

      described_class.new(room: room, membership: membership).perform

      expect(room.memberships.exists?(user_id: member.id)).to be false
    end

    it 'does not remove the room creator' do
      membership = room.memberships.find_by!(user: creator)

      expect do
        described_class.new(room: room, membership: membership).perform
      end.to raise_error(Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.room_creator_cannot_be_removed'))
    end
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::InternalChat::CreateRoomService do
  let!(:account) { create(:account) }
  let!(:creator) { create(:user, account: account) }
  let!(:member) { create(:user, account: account) }

  describe '#perform' do
    it 'creates a named room with the creator as admin' do
      room = described_class.new(account: account, current_user: creator).perform(
        name: 'Operacoes',
        user_ids: [member.id]
      )

      expect(room).to be_room
      expect(room.name).to eq('Operacoes')
      expect(room.members).to contain_exactly(creator, member)
      expect(room.memberships.find_by(user: creator)).to be_admin
      expect(room.memberships.find_by(user: member)).to be_member
    end

    it 'rejects users outside the current account' do
      external_user = create(:user)

      expect do
        described_class.new(account: account, current_user: creator).perform(
          name: 'Operacoes',
          user_ids: [external_user.id]
        )
      end.to raise_error(Ibsoft::InternalChat::Error)
    end
  end
end

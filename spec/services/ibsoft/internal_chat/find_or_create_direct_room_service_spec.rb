require 'rails_helper'

RSpec.describe Ibsoft::InternalChat::FindOrCreateDirectRoomService do
  let!(:account) { create(:account) }
  let!(:current_user) { create(:user, account: account) }
  let!(:target_user) { create(:user, account: account) }

  describe '#perform' do
    it 'creates one direct room per pair of agents' do
      service = described_class.new(account: account, current_user: current_user)

      first_room = service.perform(target_user_id: target_user.id)
      second_room = service.perform(target_user_id: target_user.id)

      expect(first_room).to eq(second_room)
      expect(first_room).to be_direct
      expect(first_room.name).to be_blank
      expect(first_room.members).to contain_exactly(current_user, target_user)
    end

    it 'does not allow a direct room with the current user' do
      expect do
        described_class.new(account: account, current_user: current_user).perform(
          target_user_id: current_user.id
        )
      end.to raise_error(Ibsoft::InternalChat::Error)
    end
  end
end

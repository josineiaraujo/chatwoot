require 'rails_helper'

RSpec.describe Ibsoft::InternalChat::UpdateRoomService do
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
    it 'updates the room name and cover image' do
      updated_room = described_class.new(room: room, current_user: creator).perform(
        name: 'Suporte interno',
        cover_image: Rack::Test::UploadedFile.new(
          Rails.root.join('spec/assets/avatar.png'),
          'image/png'
        )
      )

      expect(updated_room.name).to eq('Suporte interno')
      expect(updated_room.cover_image).to be_attached
    end

    it 'allows a regular member to update the cover image' do
      updated_room = described_class.new(room: room, current_user: member).perform(
        name: room.name,
        cover_image: Rack::Test::UploadedFile.new(
          Rails.root.join('spec/assets/avatar.png'),
          'image/png'
        )
      )

      expect(updated_room.cover_image).to be_attached
    end

    it 'does not allow a regular member to rename the room' do
      expect do
        described_class.new(room: room, current_user: member).perform(name: 'Outro nome')
      end.to raise_error(Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.only_creator_can_rename_room'))
    end
  end
end

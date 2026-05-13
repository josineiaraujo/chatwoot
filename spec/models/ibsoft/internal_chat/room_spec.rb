require 'rails_helper'

RSpec.describe Ibsoft::InternalChat::Room do
  let!(:account) { create(:account) }
  let!(:current_user) { create(:user, account: account) }
  let!(:peer) { create(:user, account: account) }
  let!(:administrator) { create(:user, :administrator, account: account) }

  before do
    Current.account = account
    peer.current_account_user.update!(availability: :busy, auto_offline: false)
  end

  after do
    Current.account = nil
  end

  describe '#payload_for' do
    it 'includes member thumbnail and availability status' do
      room = Ibsoft::InternalChat::FindOrCreateDirectRoomService.new(
        account: account,
        current_user: current_user
      ).perform(target_user_id: peer.id)

      member_payload = room.payload_for(current_user)[:members].find { |member| member[:id] == peer.id }

      expect(member_payload).to include(
        avatar_url: peer.avatar_url,
        thumbnail: peer.avatar_url,
        availability_status: 'busy'
      )
    end

    it 'includes the cover image URL when a room has a cover image' do
      room = described_class.create!(
        account: account,
        created_by: current_user,
        name: 'Operacoes',
        room_type: :room
      )
      room.cover_image.attach(
        io: Rails.root.join('spec/assets/avatar.png').open,
        filename: 'avatar.png',
        content_type: 'image/png'
      )

      expect(room.payload_for(current_user)[:cover_image_url]).to include('/rails/active_storage/')
    end

    it 'includes room permissions for creator and regular members' do
      room = Ibsoft::InternalChat::CreateRoomService.new(
        account: account,
        current_user: current_user
      ).perform(name: 'Operacoes', user_ids: [peer.id])

      creator_permissions = room.payload_for(current_user)[:permissions]
      member_permissions = room.payload_for(peer)[:permissions]
      administrator_permissions = room.payload_for(administrator)[:permissions]

      expect(creator_permissions).to include(
        update_cover_image: true,
        manage_members: true,
        destroy: true
      )
      expect(member_permissions).to include(
        update_cover_image: true,
        manage_members: false,
        destroy: false
      )
      expect(administrator_permissions).to include(
        update_cover_image: false,
        manage_members: false,
        destroy: true
      )
    end

    it 'does not expose direct chat details to non-participant administrators in the payload' do
      room = Ibsoft::InternalChat::FindOrCreateDirectRoomService.new(
        account: account,
        current_user: current_user
      ).perform(target_user_id: peer.id)

      payload = room.payload_for(administrator)

      expect(payload[:display_name]).to eq(I18n.t('ibsoft_internal_chat.direct_room_fallback'))
      expect(payload[:members]).to be_empty
      expect(payload[:last_message]).to be_nil
      expect(payload[:permissions]).to include(
        update_cover_image: false,
        manage_members: false,
        destroy: true
      )
    end

    it 'ignores orphaned memberships while building the member list' do
      room = Ibsoft::InternalChat::CreateRoomService.new(
        account: account,
        current_user: current_user
      ).perform(name: 'Operacoes', user_ids: [peer.id])
      membership = room.memberships.find_by!(user: peer)
      orphaned_user_id = User.maximum(:id) + 1000
      ActiveRecord::Base.connection.execute(
        "UPDATE ibsoft_internal_chat_memberships SET user_id = #{orphaned_user_id} WHERE id = #{membership.id}"
      )

      member_ids = room.reload.payload_for(current_user)[:members].pluck(:id)

      expect(member_ids).to contain_exactly(current_user.id)
    end
  end
end

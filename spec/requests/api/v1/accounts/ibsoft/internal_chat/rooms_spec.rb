require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::InternalChat::Rooms', type: :request do
  let!(:account) { create(:account) }
  let!(:sender) { create(:user, account: account) }
  let!(:recipient) { create(:user, account: account) }
  let!(:administrator) { create(:user, :administrator, account: account) }
  let(:headers) { { api_access_token: recipient.access_token.token } }
  let(:administrator_headers) { { api_access_token: administrator.access_token.token } }
  let(:rooms_url) { "/api/v1/accounts/#{account.id}/ibsoft/internal_chat/rooms" }

  describe 'GET /api/v1/accounts/:account_id/ibsoft/internal_chat/rooms' do
    it 'returns unread counts for direct chats and rooms' do
      direct_room = Ibsoft::InternalChat::FindOrCreateDirectRoomService.new(
        account: account,
        current_user: sender
      ).perform(target_user_id: recipient.id)
      room = Ibsoft::InternalChat::CreateRoomService.new(
        account: account,
        current_user: sender
      ).perform(name: 'Operacao', user_ids: [recipient.id])

      direct_room.memberships
                 .find_by!(user: recipient)
                 .update!(last_read_at: 1.day.ago)
      room.memberships
          .find_by!(user: recipient)
          .update!(last_read_at: 1.day.ago)

      Ibsoft::InternalChat::Message.create!(
        account: account,
        room: direct_room,
        sender: sender,
        content: 'Mensagem direta'
      )
      Ibsoft::InternalChat::Message.create!(
        account: account,
        room: room,
        sender: sender,
        content: 'Mensagem da sala'
      )

      get rooms_url, headers: headers, as: :json

      expect(response).to have_http_status(:success)

      direct_payload = response.parsed_body.find do |item|
        item['id'] == direct_room.id
      end
      room_payload = response.parsed_body.find { |item| item['id'] == room.id }

      expect(direct_payload).to include(
        'room_type' => 'direct',
        'unread_count' => 1
      )
      expect(room_payload).to include('room_type' => 'room', 'unread_count' => 1)
    end

    it 'does not list chats for administrators who are not participants' do
      direct_room = Ibsoft::InternalChat::FindOrCreateDirectRoomService.new(
        account: account,
        current_user: sender
      ).perform(target_user_id: recipient.id)

      get rooms_url, headers: administrator_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).not_to include(direct_room.id)
    end
  end

  describe 'GET /api/v1/accounts/:account_id/ibsoft/internal_chat/rooms/unread_count' do
    it 'returns the number of rooms with unread messages without returning room payloads' do
      direct_room = Ibsoft::InternalChat::FindOrCreateDirectRoomService.new(
        account: account,
        current_user: sender
      ).perform(target_user_id: recipient.id)
      direct_room.memberships.find_by!(user: recipient).update!(last_read_at: 1.day.ago)

      2.times do |index|
        Ibsoft::InternalChat::Message.create!(
          account: account,
          room: direct_room,
          sender: sender,
          content: "Mensagem direta #{index}"
        )
      end

      get "#{rooms_url}/unread_count", headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to eq(1)
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/ibsoft/internal_chat/rooms/:id' do
    it 'allows administrators to delete chats they do not participate in' do
      direct_room = Ibsoft::InternalChat::FindOrCreateDirectRoomService.new(
        account: account,
        current_user: sender
      ).perform(target_user_id: recipient.id)

      delete "#{rooms_url}/#{direct_room.id}", headers: administrator_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(Ibsoft::InternalChat::Room.exists?(direct_room.id)).to be false
    end
  end
end

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::InternalChat::Reads', type: :request do
  let!(:account) { create(:account) }
  let!(:sender) { create(:user, account: account) }
  let!(:recipient) { create(:user, account: account) }
  let!(:room) do
    Ibsoft::InternalChat::FindOrCreateDirectRoomService.new(
      account: account,
      current_user: sender
    ).perform(target_user_id: recipient.id)
  end
  let!(:message) do
    Ibsoft::InternalChat::Message.create!(
      account: account,
      room: room,
      sender: sender,
      content: 'Mensagem direta'
    )
  end
  let(:headers) { { api_access_token: recipient.access_token.token } }
  let(:membership) { room.memberships.find_by!(user: recipient) }
  let(:read_url) { "/api/v1/accounts/#{account.id}/ibsoft/internal_chat/rooms/#{room.id}/read" }

  before do
    membership.update!(last_read_at: 1.day.ago, last_read_message: nil)
  end

  describe 'POST /api/v1/accounts/:account_id/ibsoft/internal_chat/rooms/:room_id/read' do
    it 'ignores read requests without the active room context' do
      expect do
        post read_url, params: { message_id: message.id }, headers: headers, as: :json
      end.not_to(change { membership.reload.last_read_message_id })

      expect(response).to have_http_status(:no_content)
    end

    it 'marks the room as read with the active room context' do
      post read_url,
           params: {
             message_id: message.id,
             read_context: 'active_room',
             active_room_id: room.id
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(membership.reload.last_read_message_id).to eq(message.id)
    end
  end
end

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::InternalChat::Messages', type: :request do
  let!(:account) { create(:account) }
  let!(:agent) { create(:user, account: account) }
  let!(:recipient) { create(:user, account: account) }
  let!(:administrator) { create(:user, :administrator, account: account) }
  let!(:room) do
    Ibsoft::InternalChat::FindOrCreateDirectRoomService.new(
      account: account,
      current_user: agent
    ).perform(target_user_id: recipient.id)
  end
  let(:headers) { { api_access_token: agent.access_token.token } }
  let(:administrator_headers) { { api_access_token: administrator.access_token.token } }
  let(:messages_url) { "/api/v1/accounts/#{account.id}/ibsoft/internal_chat/rooms/#{room.id}/messages" }
  let!(:created_messages) do
    base_time = Time.zone.parse('2026-01-01 10:00:00')

    Array.new(55) do |index|
      Ibsoft::InternalChat::Message.create!(
        account: account,
        room: room,
        sender: index.even? ? agent : recipient,
        content: "Mensagem #{index + 1}",
        created_at: base_time + index.minutes,
        updated_at: base_time + index.minutes
      )
    end
  end

  describe 'GET /api/v1/accounts/:account_id/ibsoft/internal_chat/rooms/:room_id/messages' do
    it 'returns the latest message page with pagination metadata' do
      get messages_url, headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['messages'].length).to eq(50)
      expect(response.parsed_body['messages'].first['id']).to eq(created_messages[5].id)
      expect(response.parsed_body['messages'].last['id']).to eq(created_messages.last.id)
      expect(response.parsed_body['meta']).to include(
        'has_more' => true,
        'next_before_id' => created_messages[5].id
      )
    end

    it 'returns the previous message page before the cursor' do
      get messages_url,
          params: { before_id: created_messages[5].id },
          headers: headers,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['messages'].length).to eq(5)
      expect(response.parsed_body['messages'].first['id']).to eq(created_messages.first.id)
      expect(response.parsed_body['messages'].last['id']).to eq(created_messages[4].id)
      expect(response.parsed_body['meta']).to include(
        'has_more' => false,
        'next_before_id' => created_messages.first.id
      )
    end

    it 'does not allow administrators to read chats they do not participate in' do
      get messages_url, headers: administrator_headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end

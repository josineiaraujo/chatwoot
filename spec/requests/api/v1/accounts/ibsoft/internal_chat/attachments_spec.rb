require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::InternalChat::Attachments', type: :request do
  let!(:account) { create(:account) }
  let!(:creator) { create(:user, account: account) }
  let!(:member) { create(:user, account: account) }
  let!(:room) do
    Ibsoft::InternalChat::CreateRoomService.new(
      account: account,
      current_user: creator
    ).perform(name: 'Operacoes', user_ids: [member.id])
  end
  let!(:message) do
    Ibsoft::InternalChat::Message.create!(
      account: account,
      room: room,
      sender: creator,
      content: 'Arquivo interno'
    )
  end
  let!(:attachment) do
    message.attachments.create!(
      account: account,
      file_type: :image
    ).tap do |record|
      record.file.attach(
        io: Rails.root.join('spec/assets/avatar.png').open,
        filename: 'avatar.png',
        content_type: 'image/png'
      )
    end
  end
  let(:member_headers) { { api_access_token: member.access_token.token } }
  let(:attachment_url) do
    [
      "/api/v1/accounts/#{account.id}",
      "ibsoft/internal_chat/rooms/#{room.id}",
      "attachments/#{attachment.id}"
    ].join('/')
  end
  let(:preview_url) { "#{attachment_url}/preview" }

  describe 'GET /attachments/:id' do
    it 'streams an attachment for a room member' do
      get attachment_url, headers: member_headers

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq('image/png')
      expect(response.headers['Cache-Control']).to include('no-store')
      expect(response.body).to be_present
    end

    it 'streams an image preview for a room member' do
      attachment.file.representation(:internal_chat_preview).processed

      get preview_url, headers: member_headers

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq('image/png')
      expect(response.body).to be_present
    end

    it 'asks the client to retry while a preview is still being processed' do
      scheduler = instance_double(Ibsoft::InternalChat::AttachmentPreviewScheduler, perform: true)
      allow(Ibsoft::InternalChat::AttachmentPreviewScheduler).to receive(:new).and_return(scheduler)

      get preview_url, headers: member_headers

      expect(response).to have_http_status(:accepted)
      expect(response.headers['Retry-After']).to eq('1')
      expect(response.headers['Cache-Control']).to include('no-store')
      expect(scheduler).to have_received(:perform)
    end

    it 'redirects remote storage only after authorizing the room member' do
      delivery = Ibsoft::InternalChat::AttachmentDelivery::Result.new(
        status: :redirect,
        url: 'https://storage.example.test/signed-file'
      )
      allow(Ibsoft::InternalChat::AttachmentDelivery).to receive(:new)
        .and_return(instance_double(Ibsoft::InternalChat::AttachmentDelivery, perform: delivery))

      get attachment_url, headers: member_headers

      expect(response).to have_http_status(:temporary_redirect)
      expect(response.location).to eq('https://storage.example.test/signed-file')
      expect(response.headers['Cache-Control']).to include('no-store')
    end

    it 'denies access immediately after the member is removed' do
      membership = room.memberships.find_by!(user: member)
      Ibsoft::InternalChat::RemoveMemberService
        .new(room: room, membership: membership)
        .perform

      get attachment_url, headers: member_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end

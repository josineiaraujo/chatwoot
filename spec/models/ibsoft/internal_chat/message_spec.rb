require 'rails_helper'

RSpec.describe Ibsoft::InternalChat::Message do
  let!(:account) { create(:account) }
  let!(:sender) { create(:user, account: account) }
  let!(:recipient) { create(:user, account: account) }
  let!(:room) do
    Ibsoft::InternalChat::FindOrCreateDirectRoomService.new(
      account: account,
      current_user: sender
    ).perform(target_user_id: recipient.id)
  end

  before do
    Current.account = account
    sender.current_account_user.update!(availability: :offline, auto_offline: false)
  end

  after do
    Current.account = nil
  end

  describe '#payload' do
    it 'includes sender thumbnail and availability status' do
      message = described_class.create!(
        account: account,
        room: room,
        sender: sender,
        content: 'Mensagem interna'
      )

      expect(message.payload[:sender]).to include(
        avatar_url: sender.avatar_url,
        thumbnail: sender.avatar_url,
        availability_status: 'offline'
      )
    end

    it 'includes protected original and preview URLs for image attachments' do
      message = described_class.create!(
        account: account,
        room: room,
        sender: sender,
        content: 'Mensagem interna'
      )
      attachment = message.attachments.create!(
        account: account,
        file_type: :image
      )
      attachment.file.attach(
        io: Rails.root.join('spec/assets/avatar.png').open,
        filename: 'avatar.png',
        content_type: 'image/png'
      )

      attachment_payload = message.reload.payload[:attachments].first
      attachment_path = [
        "/api/v1/accounts/#{account.id}",
        "ibsoft/internal_chat/rooms/#{room.id}",
        "attachments/#{attachment.id}"
      ].join('/')

      expect(attachment_payload[:url]).to eq(attachment_path)
      expect(attachment_payload[:preview_url]).to eq("#{attachment_path}/preview")
    end
  end
end

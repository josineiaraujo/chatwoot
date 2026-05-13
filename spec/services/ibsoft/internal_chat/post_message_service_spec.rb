require 'rails_helper'

RSpec.describe Ibsoft::InternalChat::PostMessageService do
  let!(:account) { create(:account) }
  let!(:sender) { create(:user, account: account) }
  let!(:recipient) { create(:user, account: account) }
  let!(:room) do
    Ibsoft::InternalChat::FindOrCreateDirectRoomService.new(
      account: account,
      current_user: sender
    ).perform(target_user_id: recipient.id)
  end

  describe '#perform' do
    before do
      ActiveJob::Base.queue_adapter = :test
    end

    it 'creates a message and broadcasts the room unread state to each member' do
      message = nil

      expect do
        message = described_class.new(room: room, current_user: sender).perform(
          content: 'Mensagem interna',
          attachments: []
        )
      end.to have_enqueued_job(ActionCableBroadcastJob).with(
        [sender.pubsub_token],
        'ibsoft.internal_chat.message_created',
        hash_including(
          account_id: account.id,
          room_id: room.id,
          room: hash_including(unread_count: 0)
        )
      ).and have_enqueued_job(ActionCableBroadcastJob).with(
        [recipient.pubsub_token],
        'ibsoft.internal_chat.message_created',
        hash_including(
          account_id: account.id,
          room_id: room.id,
          room: hash_including(unread_count: 1)
        )
      )

      expect(message.content).to eq('Mensagem interna')
      expect(message.sender).to eq(sender)
      expect(message.room).to eq(room)
    end

    it 'rejects blank messages without attachments' do
      expect do
        described_class.new(room: room, current_user: sender).perform(
          content: '',
          attachments: []
        )
      end.to raise_error(Ibsoft::InternalChat::Error)
    end

    it 'rejects unsupported attachment types before creating the message' do
      invalid_file = fake_upload(content_type: 'application/x-msdownload', byte_size: 1.kilobyte)

      expect do
        described_class.new(room: room, current_user: sender).perform(
          content: '',
          attachments: [invalid_file]
        )
      end.to raise_error(Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.file_type_not_supported'))
        .and not_change(Ibsoft::InternalChat::Message, :count)
    end

    it 'rejects attachments above the configured upload size' do
      allow(GlobalConfigService).to receive(:load).with('MAXIMUM_FILE_UPLOAD_SIZE', 40).and_return('1')
      large_file = fake_upload(content_type: 'application/pdf', byte_size: 2.megabytes)

      expect do
        described_class.new(room: room, current_user: sender).perform(
          content: '',
          attachments: [large_file]
        )
      end.to raise_error(Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.file_too_large', size: 1))
    end

    it 'rejects messages with too many attachments' do
      file = fake_upload(content_type: 'application/pdf', byte_size: 1.kilobyte)
      files = Array.new(Message::NUMBER_OF_PERMITTED_ATTACHMENTS + 1, file)

      expect do
        described_class.new(room: room, current_user: sender).perform(
          content: '',
          attachments: files
        )
      end.to raise_error(
        Ibsoft::InternalChat::Error,
        I18n.t(
          'ibsoft_internal_chat.errors.too_many_attachments',
          count: Message::NUMBER_OF_PERMITTED_ATTACHMENTS
        )
      )
    end
  end

  def fake_upload(content_type:, byte_size:)
    Object.new.tap do |file|
      file.define_singleton_method(:content_type) { content_type }
      file.define_singleton_method(:byte_size) { byte_size }
    end
  end
end

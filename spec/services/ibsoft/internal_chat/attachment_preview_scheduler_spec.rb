require 'rails_helper'

RSpec.describe Ibsoft::InternalChat::AttachmentPreviewScheduler do
  let!(:account) { create(:account) }
  let!(:sender) { create(:user, account: account) }
  let!(:room) do
    Ibsoft::InternalChat::CreateRoomService.new(
      account: account,
      current_user: sender
    ).perform(name: 'Operacoes', user_ids: [])
  end
  let!(:message) do
    Ibsoft::InternalChat::Message.create!(
      account: account,
      room: room,
      sender: sender,
      content: 'Arquivo interno'
    )
  end
  let!(:attachment) do
    message.attachments.create!(account: account, file_type: :image).tap do |record|
      record.file.attach(
        io: Rails.root.join('spec/assets/avatar.png').open,
        filename: 'avatar.png',
        content_type: 'image/png'
      )
    end
  end

  it 'schedules an unprocessed image variant without processing it inline' do
    variant = attachment.file.representation(:internal_chat_preview)
    allow(Redis::Alfred).to receive(:set).and_return(true)

    expect(variant).not_to receive(:processed)
    expect(variant.blob).to receive(:preprocessed).with(variant.variation.transformations)

    described_class.new(streamable: variant).perform
  end

  it 'does not schedule the same variant while the distributed lock is active' do
    variant = attachment.file.representation(:internal_chat_preview)
    allow(Redis::Alfred).to receive(:set).and_return(false)

    expect(variant.blob).not_to receive(:preprocessed)

    described_class.new(streamable: variant).perform
  end

  it 'schedules native preview generation when a video previewer is available' do
    preview = ActiveStorage::Preview.new(
      attachment.file.blob,
      resize_to_limit: Ibsoft::InternalChat::Attachment::PREVIEW_RESIZE_TO_LIMIT
    )
    allow(Redis::Alfred).to receive(:set).and_return(true)

    expect(preview.blob).to receive(:create_preview_image_later)
      .with([preview.variation.transformations])

    described_class.new(streamable: preview).perform
  end

  it 'releases its distributed lock when enqueueing fails' do
    variant = attachment.file.representation(:internal_chat_preview)
    allow(Redis::Alfred).to receive(:set).and_return(true)
    allow(variant.blob).to receive(:preprocessed).and_raise(ActiveStorage::IntegrityError)
    allow(Redis::Alfred).to receive(:delete_if_equals)

    expect do
      described_class.new(streamable: variant).perform
    end.to raise_error(ActiveStorage::IntegrityError)

    expect(Redis::Alfred).to have_received(:delete_if_equals).once
  end
end

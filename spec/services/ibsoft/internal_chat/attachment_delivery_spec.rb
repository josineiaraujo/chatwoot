require 'rails_helper'

RSpec.describe Ibsoft::InternalChat::AttachmentDelivery do
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

  it 'streams an original attachment from disk storage' do
    result = described_class.new(streamable: attachment.file).perform

    expect(result).to be_stream
    expect(result.streamable).to eq(attachment.file)
  end

  it 'returns pending without processing a preview in the web request' do
    preview = attachment.file.representation(:internal_chat_preview)

    expect(preview).not_to receive(:processed)

    result = described_class.new(streamable: preview).perform

    expect(result).to be_pending
  end

  it 'streams an asynchronously prepared preview from disk storage' do
    preview = attachment.file.representation(:internal_chat_preview).processed

    result = described_class.new(streamable: preview).perform

    expect(result).to be_stream
  end

  it 'returns a short-lived service URL for remote storage' do
    remote_service = Object.new
    allow(attachment.file).to receive(:service).and_return(remote_service)
    allow(attachment.file).to receive(:url)
      .with(expires_in: described_class::SIGNED_URL_TTL, disposition: :inline)
      .and_return('https://storage.example.test/signed-file')

    result = described_class.new(streamable: attachment.file).perform

    expect(result).to be_redirect
    expect(result.url).to eq('https://storage.example.test/signed-file')
  end

  it 'returns missing when no streamable was provided' do
    result = described_class.new(streamable: nil).perform

    expect(result.status).to eq(:missing)
  end
end

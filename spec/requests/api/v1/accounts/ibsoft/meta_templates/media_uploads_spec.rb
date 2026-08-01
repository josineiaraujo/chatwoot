require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::MetaTemplates::MediaUploads', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:inbox) { channel.inbox }
  let(:url) do
    "/api/v1/accounts/#{account.id}/ibsoft/meta_templates/inboxes/#{inbox.id}/media_uploads"
  end

  it 'returns only the reusable Meta handle and safe file metadata' do
    file = fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png')
    uploader = instance_double(
      Ibsoft::MetaTemplates::MediaUploader,
      call: {
        handle: 'meta-media-handle',
        filename: 'avatar.png',
        content_type: 'image/png',
        size: file.size
      }
    )
    allow(Ibsoft::MetaTemplates::MediaUploader).to receive(:new)
      .with(channel: channel, file: kind_of(ActionDispatch::Http::UploadedFile))
      .and_return(uploader)

    post url,
         params: { file: file },
         headers: { api_access_token: admin.access_token.token }

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to eq(
      'handle' => 'meta-media-handle',
      'filename' => 'avatar.png',
      'content_type' => 'image/png',
      'size' => file.size
    )
  end
end

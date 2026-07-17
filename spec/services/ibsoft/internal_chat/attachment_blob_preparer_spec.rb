require 'rails_helper'

RSpec.describe Ibsoft::InternalChat::AttachmentBlobPreparer do
  it 'uploads the blob before it is attached to a message transaction' do
    upload = Rack::Test::UploadedFile.new(Rails.root.join('spec/assets/avatar.png'), 'image/png')

    prepared = described_class.new(files: [{ file: upload, file_type: :image }]).perform.first

    expect(prepared.file_type).to eq(:image)
    expect(prepared.blob).to be_persisted
    expect(prepared.blob.service_name).to eq(ActiveStorage::Blob.service.name.to_s)
    expect(prepared.blob.attachments).to be_empty
  ensure
    prepared&.blob&.purge
  end

  it 'purges already uploaded blobs when a later upload fails' do
    uploaded_blob = instance_double(ActiveStorage::Blob)
    attachments = instance_double(ActiveRecord::Associations::CollectionProxy, exists?: false)
    allow(uploaded_blob).to receive(:attachments).and_return(attachments)
    allow(uploaded_blob).to receive(:purge_later)
    upload_count = 0
    allow(ActiveStorage::Blob).to receive(:create_and_upload!) do
      upload_count += 1
      raise ActiveStorage::IntegrityError if upload_count == 2

      uploaded_blob
    end

    files = [fake_upload('first.png'), fake_upload('second.png')].map do |file|
      { file: file, file_type: :image }
    end

    expect do
      described_class.new(files: files).perform
    end.to raise_error(ActiveStorage::IntegrityError)

    expect(uploaded_blob).to have_received(:purge_later).once
  end

  def fake_upload(filename)
    StringIO.new('image').tap do |file|
      file.define_singleton_method(:original_filename) { filename }
      file.define_singleton_method(:content_type) { 'image/png' }
    end
  end
end

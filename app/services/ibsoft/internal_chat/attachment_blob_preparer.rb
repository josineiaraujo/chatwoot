class Ibsoft::InternalChat::AttachmentBlobPreparer
  PreparedAttachment = Struct.new(:blob, :file_type, keyword_init: true)

  def initialize(files:)
    @files = files
  end

  def perform
    files.map { |entry| prepare(entry) }
  rescue StandardError
    purge_unattached_blobs
    raise
  end

  def purge_unattached_blobs
    attachments_to_purge = prepared_attachments.dup
    prepared_attachments.clear

    attachments_to_purge.each do |prepared_attachment|
      blob = prepared_attachment.blob
      blob.purge_later unless blob.attachments.exists?
    end
  end

  private

  attr_reader :files

  def prepare(entry)
    file = entry.fetch(:file)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: upload_io(file),
      filename: filename(file),
      content_type: file.content_type.to_s
    )

    PreparedAttachment.new(blob: blob, file_type: entry.fetch(:file_type)).tap do |prepared_attachment|
      prepared_attachments << prepared_attachment
    end
  end

  def prepared_attachments
    @prepared_attachments ||= []
  end

  def upload_io(file)
    io = file.respond_to?(:tempfile) ? file.tempfile : file
    io.rewind if io.respond_to?(:rewind)
    io
  end

  def filename(file)
    return file.original_filename if file.respond_to?(:original_filename) && file.original_filename.present?
    return file.filename.to_s if file.respond_to?(:filename) && file.filename.present?
    return File.basename(file.path) if file.respond_to?(:path) && file.path.present?

    'attachment'
  end
end

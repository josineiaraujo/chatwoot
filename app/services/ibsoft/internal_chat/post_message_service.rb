class Ibsoft::InternalChat::PostMessageService
  MAX_ATTACHMENTS = ::Message::NUMBER_OF_PERMITTED_ATTACHMENTS
  ACCEPTABLE_FILE_TYPES = ::Attachment::ACCEPTABLE_FILE_TYPES

  def initialize(room:, current_user:)
    @room = room
    @current_user = current_user
  end

  def perform(content:, attachments: [])
    files = Array(attachments).compact
    normalized_content = content.to_s.strip
    raise Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.blank_message') if normalized_content.blank? && files.blank?

    validate_files!(files)

    prepared_attachments = prepare_attachments(files)
    message = create_message(normalized_content, prepared_attachments)
    broadcast_message(message)
    message
  rescue StandardError
    attachment_preparer&.purge_unattached_blobs
    raise
  end

  private

  attr_reader :attachment_preparer

  def validate_files!(files)
    if files.size > MAX_ATTACHMENTS
      raise Ibsoft::InternalChat::Error,
            I18n.t('ibsoft_internal_chat.errors.too_many_attachments', count: MAX_ATTACHMENTS)
    end

    files.each { |file| validate_file!(file) }
  end

  def validate_file!(file)
    validate_file_size!(file)
    validate_file_content_type!(file)
  end

  def validate_file_size!(file)
    return if file_size(file) <= maximum_file_upload_size.megabytes

    raise Ibsoft::InternalChat::Error,
          I18n.t('ibsoft_internal_chat.errors.file_too_large', size: maximum_file_upload_size)
  end

  def validate_file_content_type!(file)
    content_type = file_content_type(file)
    return if media_file?(content_type) || ACCEPTABLE_FILE_TYPES.include?(content_type)

    raise Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.file_type_not_supported')
  end

  def prepare_attachments(files)
    @attachment_preparer = Ibsoft::InternalChat::AttachmentBlobPreparer.new(
      files: files.map { |file| { file: file, file_type: file_type_for(file) } }
    )
    attachment_preparer.perform
  end

  def create_message(content, prepared_attachments)
    Ibsoft::InternalChat::Message.transaction do
      message = @room.messages.create!(
        account: @room.account,
        sender: @current_user,
        message_type: :text,
        content: content
      )

      prepared_attachments.each do |prepared_attachment|
        attachment = message.attachments.build(
          account: @room.account,
          file_type: prepared_attachment.file_type
        )
        attachment.file.attach(prepared_attachment.blob)
        attachment.save!
      end

      message
    end
  end

  def broadcast_message(message)
    @room.reload.members.find_each do |member|
      next if member.pubsub_token.blank?

      ActionCableBroadcastJob.perform_later(
        [member.pubsub_token],
        'ibsoft.internal_chat.message_created',
        {
          account_id: @room.account_id,
          room_id: @room.id,
          room: @room.payload_for(member),
          message: message.payload
        }
      )
    end
  end

  def file_type_for(file)
    content_type = file_content_type(file)
    return :image if content_type.start_with?('image/')
    return :audio if content_type.start_with?('audio/')
    return :video if content_type.start_with?('video/')

    :file
  end

  def media_file?(content_type)
    content_type.start_with?('image/', 'audio/', 'video/')
  end

  def file_content_type(file)
    return file.content_type.to_s if file.respond_to?(:content_type)

    ''
  end

  def file_size(file)
    return file.size if file.respond_to?(:size)
    return file.byte_size if file.respond_to?(:byte_size)

    0
  end

  def maximum_file_upload_size
    limit_mb = GlobalConfigService.load('MAXIMUM_FILE_UPLOAD_SIZE', 40).to_i
    limit_mb.positive? ? limit_mb : 40
  end
end

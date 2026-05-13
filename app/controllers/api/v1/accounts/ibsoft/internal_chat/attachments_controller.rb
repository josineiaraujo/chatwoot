class Api::V1::Accounts::Ibsoft::InternalChat::AttachmentsController < Api::V1::Accounts::Ibsoft::InternalChat::BaseController
  before_action :fetch_room
  before_action :fetch_attachment

  def show
    authorize @room, :show?

    stream_attachment(@attachment.file)
  end

  def preview
    authorize @room, :show?

    preview = preview_attachment
    return head :not_found if preview.blank?

    stream_attachment(
      preview,
      content_type: preview_content_type,
      filename: @attachment.file.filename
    )
  end

  private

  def fetch_attachment
    @attachment = Ibsoft::InternalChat::Attachment
                  .joins(:message)
                  .where(
                    account_id: Current.account.id,
                    ibsoft_internal_chat_messages: {
                      room_id: @room.id,
                      deleted_at: nil
                    }
                  )
                  .find(params[:id])
  end

  def preview_attachment
    return unless @attachment.file.attached?
    return @attachment.file unless @attachment.file.representable?
    return unless @attachment.image? || @attachment.video?

    @attachment.file
               .representation(resize_to_limit: Ibsoft::InternalChat::Attachment::PREVIEW_RESIZE_TO_LIMIT)
               .processed
  rescue ActiveStorage::UnrepresentableError
    @attachment.image? ? @attachment.file : nil
  end

  def preview_content_type
    return @attachment.file.content_type if @attachment.image?

    'image/png'
  end

  def stream_attachment(streamable, content_type: nil, filename: nil)
    return head :not_found if streamable.blank?

    response.headers['Content-Type'] = content_type || streamable.content_type
    response.headers['Content-Disposition'] = content_disposition(filename || streamable.filename)
    response.headers['Content-Length'] = streamable.byte_size.to_s if streamable.respond_to?(:byte_size)
    response.headers['Cache-Control'] = 'private, no-store'
    self.response_body = Enumerator.new do |stream|
      streamable.download { |chunk| stream << chunk }
    end
  end

  def content_disposition(filename)
    ActionDispatch::Http::ContentDisposition.format(
      disposition: 'inline',
      filename: filename.to_s
    )
  end
end

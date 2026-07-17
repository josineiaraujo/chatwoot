class Api::V1::Accounts::Ibsoft::InternalChat::AttachmentsController < Api::V1::Accounts::Ibsoft::InternalChat::BaseController
  before_action :fetch_room
  before_action :fetch_attachment

  def show
    authorize @room, :show?

    deliver_attachment(@attachment.file)
  end

  def preview
    authorize @room, :show?

    deliver_attachment(
      preview_attachment,
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

    @attachment.file.representation(:internal_chat_preview)
  rescue ActiveStorage::UnrepresentableError
    @attachment.image? ? @attachment.file : nil
  end

  def deliver_attachment(streamable, content_type: nil, filename: nil)
    delivery = Ibsoft::InternalChat::AttachmentDelivery.new(streamable: streamable).perform
    return stream_attachment(delivery.streamable, content_type: content_type, filename: filename) if delivery.stream?
    return redirect_to_remote_attachment(delivery.url) if delivery.redirect?
    return preview_pending(streamable) if delivery.pending?

    head :not_found
  end

  def redirect_to_remote_attachment(url)
    response.headers['Cache-Control'] = 'private, no-store'
    redirect_to url, allow_other_host: true, status: :temporary_redirect
  end

  def preview_pending(streamable)
    Ibsoft::InternalChat::AttachmentPreviewScheduler.new(streamable: streamable).perform
    response.headers['Cache-Control'] = 'private, no-store'
    response.headers['Retry-After'] = '1'
    head :accepted
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

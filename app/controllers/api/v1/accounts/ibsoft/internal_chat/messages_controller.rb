class Api::V1::Accounts::Ibsoft::InternalChat::MessagesController < Api::V1::Accounts::Ibsoft::InternalChat::BaseController
  PAGE_SIZE = 50
  CURSOR_CONDITION = <<~SQL.squish
    ibsoft_internal_chat_messages.created_at < :created_at OR
    (ibsoft_internal_chat_messages.created_at = :created_at AND ibsoft_internal_chat_messages.id < :id)
  SQL

  before_action :fetch_room

  def index
    authorize @room, :show?

    messages = messages_page

    render json: {
      messages: messages[:records].map(&:payload),
      meta: {
        has_more: messages[:has_more],
        next_before_id: messages[:records].first&.id
      }
    }
  end

  def create
    authorize @room, :post_message?

    message = Ibsoft::InternalChat::PostMessageService.new(
      room: @room,
      current_user: current_user
    ).perform(content: message_params[:content], attachments: params[:attachments])

    Ibsoft::InternalChat::MarkAsReadService.new(room: @room, current_user: current_user).perform(message_id: message.id)

    render json: message.payload, status: :created
  end

  private

  def messages_page
    cursor = cursor_message
    return empty_page if params[:before_id].present? && cursor.blank?

    records = messages_scope(cursor).limit(PAGE_SIZE + 1).to_a
    page_records = records.first(PAGE_SIZE).reverse

    {
      records: page_records,
      has_more: records.size > PAGE_SIZE
    }
  end

  def messages_scope(cursor)
    scope = @room.messages
                 .visible
                 .includes(:attachments, :sender)

    if cursor.present?
      scope = scope.where(
        CURSOR_CONDITION,
        created_at: cursor.created_at,
        id: cursor.id
      )
    end

    scope.order(created_at: :desc, id: :desc)
  end

  def cursor_message
    return if params[:before_id].blank?

    @room.messages.visible.find_by(id: params[:before_id])
  end

  def empty_page
    {
      records: [],
      has_more: false
    }
  end

  def message_params
    params.permit(:content, attachments: [])
  end
end

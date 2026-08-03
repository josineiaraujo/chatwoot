class Api::V1::Accounts::Ibsoft::MessageBroadcast::BroadcastsController < Api::V1::Accounts::Ibsoft::MessageBroadcast::BaseController
  DEFAULT_PER_PAGE = 30
  MAX_PER_PAGE = 100
  RECIPIENT_KEYS = [:external_customer_id, :customer_name, :name, :primary_phone, :fallback_phone, { template_variable_values: {} }].freeze

  before_action :set_broadcast, only: [:show, :send_broadcast]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = params.fetch(:per_page, DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE)
    scope = scoped_broadcasts
    total = scope.count
    broadcasts = scope.offset((page - 1) * per_page).limit(per_page)

    render json: {
      broadcasts: collection_payloads(broadcasts),
      meta: {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: [(total.to_f / per_page).ceil, 1].max
      }
    }
  end

  def show
    render json: broadcast_payload(@broadcast)
  end

  def send_broadcast
    return render_invalid_channel unless whatsapp_cloud_inbox?(@broadcast.inbox)
    return render_invalid_dispatch unless valid_dispatch?(@broadcast.dispatch_mode, @broadcast.source_type, @broadcast.recipients.to_a)

    queue_result = queue_broadcast!(@broadcast)
    return render_empty_recipients if queue_result == Ibsoft::MessageBroadcast::QueueBroadcast::RESULT_WITHOUT_RECIPIENTS
    return render_invalid_status unless queue_result == Ibsoft::MessageBroadcast::QueueBroadcast::RESULT_QUEUED

    dispatch_broadcast(@broadcast)

    render json: broadcast_payload(@broadcast.reload)
  end

  def create
    return unless ensure_active_erp_connection!

    recipients = recipient_attributes
    return unless valid_create_request?(recipients)

    broadcast = Ibsoft::MessageBroadcast::Broadcast.transaction do
      create_broadcast!(recipients)
    end
    dispatch_broadcast(broadcast) if send_now?

    render json: broadcast_payload(broadcast.reload)
  end

  private

  def scoped_broadcasts
    Ibsoft::MessageBroadcast::Broadcast
      .where(account: Current.account)
      .includes(:created_by)
      .order(created_at: :desc, id: :desc)
  end

  def collection_payloads(broadcasts)
    records = broadcasts.to_a
    recipient_counts = Ibsoft::MessageBroadcast::Recipient
                       .where(broadcast_id: records.map(&:id))
                       .group(:broadcast_id)
                       .count

    records.map do |broadcast|
      broadcast.payload(recipients_count: recipient_counts.fetch(broadcast.id, 0))
    end
  end

  def set_broadcast
    @broadcast = scoped_broadcasts.find(params[:id])
  end

  def broadcast_attributes
    params.permit(
      :source_type,
      :dispatch_mode,
      :template_name,
      :template_language,
      :conversation_mode
    ).to_h.merge(
      status: 'draft',
      template_variables: template_variables
    )
  end

  def template_variables
    return {} unless params[:template_variables].respond_to?(:to_unsafe_h)

    params[:template_variables].to_unsafe_h.transform_values do |variable|
      normalize_template_variable(variable)
    end
  end

  def normalize_template_variable(variable)
    normalized_variable = variable.to_h
    return normalized_variable unless normalized_variable['type'] == 'fixed'

    normalized_variable.merge('value' => normalized_variable['value'].to_s.gsub(/[\r\n]+/, ' ').strip)
  end

  def assign_optional_associations(broadcast)
    broadcast.assignee = Current.account.users.find(params[:assignee_id]) if params[:assignee_id].present?
    broadcast.team = Current.account.teams.find(params[:team_id]) if params[:team_id].present?
  end

  def create_broadcast!(recipients)
    broadcast = Ibsoft::MessageBroadcast::Broadcast.new(broadcast_attributes)
    broadcast.account = Current.account
    broadcast.created_by = Current.user
    broadcast.erp_connection = active_erp_connection
    broadcast.inbox = selected_inbox
    assign_optional_associations(broadcast)
    broadcast.save!
    create_recipients(broadcast, recipients)
    queue_broadcast!(broadcast) if send_now?
    broadcast
  end

  def create_recipients(broadcast, recipients)
    recipients.each do |attributes|
      broadcast.recipients.create!(attributes)
    end
  end

  def queue_broadcast!(broadcast)
    Ibsoft::MessageBroadcast::QueueBroadcast.new(
      broadcast: broadcast,
      sent_by: Current.user
    ).call
  end

  def send_now?
    @send_now ||= ActiveModel::Type::Boolean.new.cast(params[:send_now])
  end

  def recipient_attributes
    collection_param(:recipients).filter_map do |recipient|
      Ibsoft::MessageBroadcast::RecipientAttributesBuilder.new(
        attributes: permitted_hash(recipient, RECIPIENT_KEYS)
      ).call
    end
  end

  def broadcast_payload(broadcast)
    broadcast.payload.merge(
      recipients: broadcast.recipients.order(:customer_name).map(&:payload)
    )
  end

  def render_invalid_status
    render json: { error: 'broadcast_not_draft' }, status: :unprocessable_content
  end

  def render_empty_recipients
    render json: { error: 'broadcast_without_pending_recipients' }, status: :unprocessable_content
  end

  def render_invalid_dispatch
    render json: { error: 'invalid_broadcast_dispatch' }, status: :unprocessable_content
  end

  def render_invalid_channel
    render json: { error: 'invalid_whatsapp_cloud_inbox' }, status: :unprocessable_content
  end

  def dispatch_mode
    params[:dispatch_mode].presence || 'bulk'
  end

  def valid_create_request?(recipients)
    error = create_request_error(recipients)
    return true if error.blank?

    render_create_request_error(error)
    false
  end

  def create_request_error(recipients)
    return :invalid_channel unless whatsapp_cloud_inbox?(selected_inbox)
    return :invalid_dispatch unless valid_dispatch?(dispatch_mode, params[:source_type], recipients)
    return :empty_recipients if send_now? && recipients.none? { |recipient| recipient[:status] == 'pending' }
  end

  def render_create_request_error(error)
    return render_invalid_channel if error == :invalid_channel
    return render_invalid_dispatch if error == :invalid_dispatch

    render_empty_recipients
  end

  def valid_dispatch?(mode, source_type, recipients)
    return true unless mode == 'single'

    source_type == 'selection' && recipients.one?
  end

  def selected_inbox = @selected_inbox ||= Current.account.inboxes.find(params[:inbox_id])

  def whatsapp_cloud_inbox?(inbox)
    channel = inbox.channel
    channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud'
  end

  def dispatch_broadcast(broadcast)
    if broadcast.single_dispatch?
      Ibsoft::MessageBroadcast::BroadcastSender.new(broadcast: broadcast).call
    else
      Ibsoft::MessageBroadcast::SendBroadcastJob.perform_later(broadcast.id)
    end
  end
end

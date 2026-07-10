class Api::V1::Accounts::Ibsoft::MessageBroadcast::BroadcastsController < Api::V1::Accounts::Ibsoft::MessageBroadcast::BaseController
  RECIPIENT_KEYS = [:external_customer_id, :customer_name, :name, :primary_phone, :fallback_phone, { template_variable_values: {} }].freeze

  before_action :set_broadcast, only: [:show, :send_broadcast]

  def index
    render json: {
      broadcasts: scoped_broadcasts.limit(50).map(&:payload)
    }
  end

  def show
    render json: broadcast_payload(@broadcast)
  end

  def send_broadcast
    return render_invalid_status unless @broadcast.status == 'draft'
    return render_empty_recipients unless @broadcast.recipients.exists?(status: 'pending')

    queue_broadcast!(@broadcast)
    Ibsoft::MessageBroadcast::SendBroadcastJob.perform_later(@broadcast.id)

    render json: broadcast_payload(@broadcast.reload)
  end

  def create
    return unless ensure_active_erp_connection!

    recipients = recipient_attributes
    return render_empty_recipients if send_now? && recipients.none? { |recipient| recipient[:status] == 'pending' }

    broadcast = Ibsoft::MessageBroadcast::Broadcast.transaction do
      create_broadcast!(recipients)
    end
    Ibsoft::MessageBroadcast::SendBroadcastJob.perform_later(broadcast.id) if send_now?

    render json: broadcast_payload(broadcast.reload)
  end

  private

  def scoped_broadcasts
    Ibsoft::MessageBroadcast::Broadcast.where(account: Current.account).order(created_at: :desc)
  end

  def set_broadcast
    @broadcast = scoped_broadcasts.find(params[:id])
  end

  def broadcast_attributes
    params.permit(
      :source_type,
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
    broadcast.inbox = Current.account.inboxes.find(params[:inbox_id])
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
    broadcast.transaction do
      broadcast.recipients.where(status: 'pending').find_each { |recipient| recipient.update!(status: 'queued') }
      broadcast.update!(status: 'queued', sent_by: Current.user)
    end
  end

  def send_now?
    @send_now ||= ActiveModel::Type::Boolean.new.cast(params[:send_now])
  end

  def recipient_attributes
    collection_param(:recipients).filter_map { |recipient| recipient_payload(recipient) }
  end

  def recipient_payload(recipient)
    normalized_recipient = permitted_hash(recipient, RECIPIENT_KEYS)
    return if normalized_recipient[:external_customer_id].blank?

    {
      external_customer_id: normalized_recipient[:external_customer_id],
      customer_name: normalized_recipient[:customer_name].presence || normalized_recipient[:name],
      primary_phone: normalized_recipient[:primary_phone],
      fallback_phone: normalized_recipient[:fallback_phone],
      template_variable_values: normalized_template_variable_values(template_variable_values_for(recipient, normalized_recipient)),
      phone_status: phone_status(normalized_recipient),
      status: recipient_status(normalized_recipient),
      error_code: recipient_error_code(normalized_recipient)
    }
  end

  def normalized_template_variable_values(values)
    return {} if values.blank?

    values = values.to_unsafe_h if values.respond_to?(:to_unsafe_h)
    return {} unless values.respond_to?(:to_h)

    values.to_h.transform_values { |value| value.to_s.gsub(/[\r\n]+/, ' ').strip }
  end

  def template_variable_values_for(raw_recipient, normalized_recipient)
    normalized_recipient[:template_variable_values].presence || raw_template_variable_values(raw_recipient)
  end

  def raw_template_variable_values(raw_recipient)
    return raw_recipient[:template_variable_values] if raw_recipient.respond_to?(:[])

    {}
  end

  def recipient_deliverable?(recipient)
    recipient[:primary_phone].present? || recipient[:fallback_phone].present?
  end

  def recipient_status(recipient)
    recipient_deliverable?(recipient) ? 'pending' : 'skipped'
  end

  def recipient_error_code(recipient)
    recipient_deliverable?(recipient) ? nil : 'without_valid_phone'
  end

  def phone_status(recipient)
    return 'primary' if recipient[:primary_phone].present?
    return 'fallback' if recipient[:fallback_phone].present?

    'unavailable'
  end

  def broadcast_payload(broadcast)
    broadcast.payload.merge(
      recipients: broadcast.recipients.order(:customer_name).map(&:payload)
    )
  end

  def render_invalid_status
    render json: { error: 'broadcast_not_draft' }, status: :unprocessable_entity
  end

  def render_empty_recipients
    render json: { error: 'broadcast_without_pending_recipients' }, status: :unprocessable_entity
  end
end

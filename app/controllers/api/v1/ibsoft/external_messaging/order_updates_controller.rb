class Api::V1::Ibsoft::ExternalMessaging::OrderUpdatesController < ActionController::API
  before_action :set_security_headers
  before_action :authenticate_endpoint!

  def create
    command = contract.call
    result = Ibsoft::ExternalMessaging::OrderUpdateCreator.new(
      endpoint: @endpoint,
      command: command,
      recipient: inbound_request.recipient
    ).call
    return render_unchanged(result.order) if result.unchanged

    enqueue(result.update) if result.created
    render json: accepted_payload(result), status: :accepted
  rescue Ibsoft::ExternalMessaging::InvalidRequest => e
    render_error(e.code, e.http_status, message: e.message)
  rescue ActiveRecord::RecordInvalid => e
    render_error('invalid_request', 422, details: e.record.errors.to_hash)
  end

  private

  def set_security_headers
    response.set_header('Cache-Control', 'no-store, no-cache, must-revalidate')
    response.set_header('Pragma', 'no-cache')
    response.set_header('X-Content-Type-Options', 'nosniff')
  end

  def authenticate_endpoint!
    @endpoint = Ibsoft::ExternalMessaging::EndpointAuthenticator.new(
      family: route_family,
      credentials: inbound_request.credentials
    ).call
  rescue Ibsoft::ExternalMessaging::InvalidRequest => e
    render_error(e.code, e.http_status, message: e.message)
  end

  def inbound_request
    @inbound_request ||= Ibsoft::ExternalMessaging::OrderUpdateInboundRequest.new(
      family: route_family,
      request_attributes: {
        method: request.request_method,
        authorization: request.authorization,
        query_parameters: request.query_parameters,
        raw_body: request.raw_post,
        media_type: request.media_type,
        content_type: request.content_type
      }
    ).call
  end

  def route_family
    request.path_parameters[:ibsoft_external_messaging_family].to_s
  end

  def contract
    Ibsoft::ExternalMessaging::OrderStatusContract.new(
      endpoint: @endpoint,
      fields: parsed_request
    )
  end

  def parsed_request
    inbound_request.fields
  end

  def enqueue(update)
    Ibsoft::ExternalMessaging::SendOrderUpdateJob.perform_later(update.id)
    update.update_column(:enqueued_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
  rescue StandardError => e
    Rails.logger.error(
      "[Ibsoft::ExternalMessaging] initial enqueue failed order_update=#{update.id} error=#{e.class}"
    )
  end

  def accepted_payload(result)
    {
      ok: true,
      status: 'accepted',
      message: I18n.t('ibsoft_external_messaging.order_updates.responses.accepted'),
      message_id: nil,
      order_update_id: result.update.id,
      reference_id: result.order.reference_id,
      order_status: result.update.order_status,
      payment_status: result.update.payment_status,
      visible_message: true
    }
  end

  def render_unchanged(order)
    render json: {
      ok: true,
      status: 'unchanged',
      message: I18n.t('ibsoft_external_messaging.order_updates.responses.unchanged'),
      reference_id: order.reference_id,
      order_status: order.order_status,
      payment_status: order.payment_status,
      visible_message: false
    }, status: :ok
  end

  def render_error(code, status, details: nil, message: nil)
    body = {
      error: {
        code: code,
        message: message || I18n.t(
          "ibsoft_external_messaging.errors.#{code}",
          default: I18n.t('ibsoft_external_messaging.errors.invalid_request')
        )
      }
    }
    body[:error][:details] = details if details.present?
    render json: body, status: status
  end
end

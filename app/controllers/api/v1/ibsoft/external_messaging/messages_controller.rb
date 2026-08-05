class Api::V1::Ibsoft::ExternalMessaging::MessagesController < ActionController::API
  before_action :set_security_headers

  def create
    result = create_delivery
    accept_delivery(result.delivery, enqueue: result.created)
  rescue Ibsoft::ExternalMessaging::InvalidRequest => e
    response.set_header('Allow', 'GET, POST') if e.code == 'ixc_method_not_allowed'
    render_error(e.code, e.http_status, message: e.message)
  rescue Ibsoft::ExternalMessaging::DeliveryCreator::IdempotencyConflict
    render_error('idempotency_conflict', :conflict)
  rescue ActiveRecord::RecordInvalid => e
    render_error('invalid_request', 422, details: e.record.errors.to_hash)
  end

  private

  def create_delivery
    payload = inbound_request
    @endpoint = authenticate_endpoint(payload)
    Ibsoft::ExternalMessaging::DeliveryCreator.new(
      endpoint: @endpoint,
      attributes: request_contract.call
    ).call
  end

  def accept_delivery(delivery, enqueue:)
    enqueue(delivery) if enqueue
    render json: accepted_payload(delivery), status: :accepted
  end

  def set_security_headers
    response.set_header('Cache-Control', 'no-store, no-cache, must-revalidate')
    response.set_header('Pragma', 'no-cache')
    response.set_header('X-Content-Type-Options', 'nosniff')
  end

  def authenticate_endpoint(payload)
    Ibsoft::ExternalMessaging::EndpointAuthenticator.new(
      instance_type: route_instance_type,
      credentials: payload.fetch(:credentials, {})
    ).call
  end

  def request_contract
    payload = inbound_request
    instance_type_definition.request_contract_class.new(
      endpoint: @endpoint,
      payload: payload,
      idempotency_key: Ibsoft::ExternalMessaging::RequestIdentityKey.new.call
    )
  end

  def inbound_request
    @inbound_request ||= instance_type_definition.request_parser_class.new(
      method: request.request_method,
      parameters: request.query_parameters,
      query_parameters: request.query_parameters,
      raw_body: request.raw_post,
      content_type: request.content_type
    ).call
  end

  def instance_type_definition
    @instance_type_definition ||=
      Ibsoft::ExternalMessaging::InstanceTypeRegistry.fetch(route_instance_type)
  end

  def route_instance_type
    request.path_parameters[:ibsoft_external_messaging_instance_type].to_s
  end

  def enqueue(delivery)
    Ibsoft::ExternalMessaging::SendDeliveryJob.perform_later(delivery.id)
    delivery.update_column(:enqueued_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
  rescue StandardError => e
    Rails.logger.error(
      "[Ibsoft::ExternalMessaging] initial enqueue failed delivery=#{delivery.id} error=#{e.class}"
    )
  end

  def accepted_payload(delivery)
    payload = {
      ok: true,
      status: 'accepted',
      message: I18n.t('ibsoft_external_messaging.responses.accepted'),
      message_id: nil,
      delivery_id: delivery.id,
      template_name: delivery.template_name,
      template_type: delivery.order_template? ? 'order' : 'simple'
    }
    payload[:reference_id] = delivery.order_reference_id if delivery.order_reference_id.present?
    payload
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

class Api::V1::Accounts::Ibsoft::ExternalMessaging::EndpointsController <
  Api::V1::Accounts::Ibsoft::ExternalMessaging::BaseController
  before_action :set_endpoint, only: [:update, :destroy, :rotate_token, :order_update_templates]

  rescue_from Ibsoft::ExternalMessaging::OrderUpdateTemplateSettings::ValidationError,
              with: :render_order_update_template_validation_error
  rescue_from Ibsoft::MetaTemplates::Client::Error, with: :render_meta_template_error

  def index
    endpoints = scoped_endpoints.to_a
    delivery_counts = Ibsoft::ExternalMessaging::Delivery
                      .where(endpoint_id: endpoints)
                      .group(:endpoint_id)
                      .count

    render json: {
      endpoints: endpoints.map do |endpoint|
        endpoint.payload(deliveries_count: delivery_counts.fetch(endpoint.id, 0))
      end,
      inboxes: whatsapp_cloud_inboxes.map { |inbox| { id: inbox.id, name: inbox.name } }
    }
  end

  def create
    endpoint = scoped_endpoints.new(endpoint_attributes)
    endpoint.created_by = Current.user
    token = endpoint.issue_token
    endpoint.save!

    render json: endpoint.payload.merge(
      Ibsoft::ExternalMessaging::InstanceCredentials.new(endpoint: endpoint).issued_payload(token)
    ), status: :created
  end

  def update
    @endpoint.assign_attributes(update_attributes)
    assign_order_defaults if params.key?(:order_defaults)
    @endpoint.save!

    render json: @endpoint.payload
  end

  def destroy
    @endpoint.update!(active: false)

    head :no_content
  end

  def rotate_token
    token = @endpoint.rotate_token!

    render json: @endpoint.payload.merge(
      Ibsoft::ExternalMessaging::InstanceCredentials.new(endpoint: @endpoint).issued_payload(token)
    )
  end

  def order_update_templates
    templates = Ibsoft::ExternalMessaging::OrderUpdateTemplateCatalog.new(endpoint: @endpoint).list

    render json: { templates: templates }
  end

  private

  def scoped_endpoints
    Ibsoft::ExternalMessaging::Endpoint
      .where(account: Current.account)
      .includes(:inbox)
      .order(active: :desc, name: :asc)
  end

  def set_endpoint
    @endpoint = scoped_endpoints.find(params[:id])
  end

  def endpoint_attributes
    params.permit(
      :name,
      :inbox_id,
      :instance_type,
      :active,
      :rate_limit_per_second,
      :retention_days,
      :allow_order_resends,
      :failure_diagnostics_enabled
    ).to_h.merge(
      account: Current.account,
      inbox: whatsapp_cloud_inboxes.find { |inbox| inbox.id == params[:inbox_id].to_i }
    )
  end

  def update_attributes
    params.permit(
      :name,
      :active,
      :rate_limit_per_second,
      :retention_days,
      :allow_order_resends,
      :failure_diagnostics_enabled
    )
  end

  def assign_order_defaults
    attributes = order_defaults_attributes

    @endpoint.order_pix_merchant_name = attributes[:merchant_name] if attributes.key?(:merchant_name)
    @endpoint.order_pix_key_type = attributes[:key_type] if attributes.key?(:key_type)
    @endpoint.order_update_messages = attributes[:messages] if attributes.key?(:messages)
    assign_order_update_delivery(attributes[:update_delivery]) if attributes.key?(:update_delivery)

    if ActiveModel::Type::Boolean.new.cast(attributes[:clear_key])
      @endpoint.order_pix_key = nil
    elsif attributes[:key].present?
      @endpoint.order_pix_key = attributes[:key]
    end
  end

  def order_defaults_attributes
    params.permit(
      order_defaults: [
        :merchant_name,
        :key,
        :key_type,
        :clear_key,
        { messages: Ibsoft::ExternalMessaging::Endpoint::ORDER_UPDATE_MESSAGE_KEYS },
        {
          update_delivery: [
            :mode,
            :default_template_id,
            { overrides: Ibsoft::ExternalMessaging::Endpoint::ORDER_UPDATE_MESSAGE_KEYS }
          ]
        }
      ]
    )
          .fetch(:order_defaults, {})
          .to_h
          .with_indifferent_access
  end

  def assign_order_update_delivery(attributes)
    Ibsoft::ExternalMessaging::OrderUpdateTemplateSettings.new(
      endpoint: @endpoint,
      attributes: attributes
    ).assign
  end

  def render_order_update_template_validation_error(error)
    render json: {
      error: error.code,
      message: error.message
    }, status: :unprocessable_entity
  end

  def render_meta_template_error(error)
    render json: {
      error: error.code,
      message: error.message
    }, status: error.http_status || :bad_gateway
  end
end

class Ibsoft::ExternalMessaging::EndpointPayload
  def initialize(endpoint:, deliveries_count: nil)
    @endpoint = endpoint
    @deliveries_count = deliveries_count
  end

  def call
    identity_payload.merge(configuration_payload, timestamp_payload)
  end

  def order_defaults
    message_catalog = Ibsoft::ExternalMessaging::OrderUpdateMessageCatalog.new(endpoint: endpoint)
    template_settings = endpoint.order_update_template_settings.to_h.deep_stringify_keys

    {
      merchant_name: endpoint.order_pix_merchant_name,
      key_type: endpoint.order_pix_key_type,
      key_configured: endpoint.order_pix_key.present?,
      key_hint: masked_order_pix_key,
      messages: message_catalog.effective,
      message_defaults: message_catalog.defaults,
      update_delivery: update_delivery_payload(template_settings)
    }
  end

  private

  attr_reader :endpoint, :deliveries_count

  def identity_payload
    {
      id: endpoint.id,
      account_id: endpoint.account_id,
      inbox_id: endpoint.inbox_id,
      inbox_name: endpoint.inbox.name,
      name: endpoint.name,
      instance_type: endpoint.instance_type,
      integration_family: instance_type_definition.family,
      public_path: instance_type_definition.public_path,
      order_update_path: instance_type_definition.order_update_path,
      token_hint: endpoint.token_hint,
      authentication: Ibsoft::ExternalMessaging::InstanceCredentials.new(endpoint: endpoint).public_payload
    }
  end

  def configuration_payload
    {
      active: endpoint.active,
      rate_limit_per_second: endpoint.rate_limit_per_second,
      deliveries_count: deliveries_count || endpoint.deliveries.count,
      retention_days: endpoint.retention_days,
      allow_order_resends: endpoint.allow_order_resends,
      failure_diagnostics_enabled: endpoint.failure_diagnostics_enabled,
      order_defaults: order_defaults,
      order_defaults_configured: endpoint.order_defaults_configured?,
      order_update_template_ready: endpoint.order_update_template_ready?
    }
  end

  def timestamp_payload
    {
      created_at: endpoint.created_at,
      updated_at: endpoint.updated_at
    }
  end

  def update_delivery_payload(template_settings)
    {
      mode: endpoint.order_update_delivery_mode,
      template_ready: endpoint.order_update_template_ready?,
      default_template: template_settings['default'],
      overrides: template_settings.fetch('overrides', {})
    }
  end

  def masked_order_pix_key
    return if endpoint.order_pix_key.blank?

    "****#{endpoint.order_pix_key.last(4)}"
  end

  def instance_type_definition
    Ibsoft::ExternalMessaging::InstanceTypeRegistry.fetch(endpoint.instance_type)
  end
end

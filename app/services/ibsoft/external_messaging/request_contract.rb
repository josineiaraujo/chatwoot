require 'digest'

class Ibsoft::ExternalMessaging::RequestContract
  MAX_COMPONENTS_BYTES = 64.kilobytes
  MAX_MESSAGE_BYTES = 32.kilobytes

  def initialize(endpoint:, payload:, idempotency_key:)
    @endpoint = endpoint
    @payload = payload.to_h.deep_symbolize_keys
    @idempotency_key = idempotency_key.to_s.strip
  end

  def call
    validate_idempotency_key!
    attributes = normalized_attributes
    attributes.merge(
      idempotency_key: idempotency_key,
      request_fingerprint: fingerprint(attributes)
    )
  end

  private

  attr_reader :endpoint, :payload, :idempotency_key

  def normalized_attributes
    attributes = template_attributes.merge(recipient: recipient)
    attributes[:message_content] = rendered_message_content(attributes)
    validate_generated_content!(attributes)
    attributes
  end

  def template_attributes
    @template_attributes ||= begin
      fields = Ibsoft::ExternalMessaging::OrderDefaultsMerger.new(
        endpoint: endpoint,
        fields: payload.fetch(:fields, {})
      ).call
      attributes = Ibsoft::ExternalMessaging::TemplatePayloadBuilder.new(fields: fields).call
      secret = Ibsoft::ExternalMessaging::OrderPixSecret.extract(attributes[:template_components])

      attributes.merge(
        template_components: secret.components,
        order_pix_key: secret.key
      )
    end
  end

  def rendered_message_content(attributes)
    Ibsoft::ExternalMessaging::TemplateContentRenderer.new(
      endpoint: endpoint,
      attributes: attributes
    ).call
  end

  def validate_idempotency_key!
    raise_error('idempotency_key_required') if idempotency_key.blank?
    raise_error('idempotency_key_invalid') if idempotency_key.bytesize > 255
  end

  def validate_generated_content!(attributes)
    raise_error('template_components_too_large') if attributes[:template_components].to_json.bytesize > MAX_COMPONENTS_BYTES
    raise_error('message_content_too_large') if attributes[:message_content].bytesize > MAX_MESSAGE_BYTES
  end

  def recipient
    value = payload[:recipient].to_s.gsub(/\D+/, '')
    raise_error('recipient_invalid') unless value.match?(/\A\d{10,15}\z/)

    value
  end

  def fingerprint(attributes)
    Digest::SHA256.hexdigest(JSON.generate(canonicalize(attributes)))
  end

  def canonicalize(value)
    case value
    when Hash
      value.deep_stringify_keys.sort.to_h.transform_values { |entry| canonicalize(entry) }
    when Array
      value.map { |entry| canonicalize(entry) }
    else
      value
    end
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end

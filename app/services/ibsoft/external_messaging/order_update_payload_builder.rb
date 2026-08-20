class Ibsoft::ExternalMessaging::OrderUpdatePayloadBuilder
  def initialize(update:)
    @update = update
  end

  def call
    update.delivery_method == 'template' ? template_payload : interactive_payload
  end

  private

  attr_reader :update

  def base_payload
    {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: update.order.recipient
    }
  end

  def template_payload
    base_payload.merge(
      type: 'template',
      template: template_definition
    )
  end

  def template_definition
    {
      name: update.template_name,
      language: {
        policy: 'deterministic',
        code: update.template_language
      }
    }.tap do |template|
      template[:components] = update.template_components if update.template_components.present?
    end
  end

  def interactive_payload
    base_payload.merge(
      type: 'interactive',
      interactive: {
        type: 'order_status',
        body: { text: update.message_content },
        action: {
          name: 'review_order',
          parameters: interactive_parameters
        }
      }
    )
  end

  def interactive_parameters
    parameters = { reference_id: update.order.reference_id }
    parameters[:order] = order_parameters if update.order_status.present?
    parameters[:payment] = payment_parameters if update.payment_status.present?
    parameters
  end

  def order_parameters
    parameters = { status: update.order_status }
    parameters[:description] = update.description if update.description.present?
    parameters
  end

  def payment_parameters
    parameters = { status: update.payment_status }
    parameters[:timestamp] = update.payment_timestamp if update.payment_timestamp.present?
    parameters
  end
end

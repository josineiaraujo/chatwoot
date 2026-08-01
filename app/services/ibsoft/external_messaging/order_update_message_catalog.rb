class Ibsoft::ExternalMessaging::OrderUpdateMessageCatalog
  PLACEHOLDER = '{{reference_id}}'.freeze
  MAX_MESSAGE_BYTES = 1024
  KEYS = %w[
    order_pending
    order_processing
    order_partially_shipped
    order_shipped
    order_completed
    order_canceled
    payment_pending
    payment_captured
    payment_failed
    captured_and_completed
  ].freeze

  def initialize(endpoint:)
    @endpoint = endpoint
  end

  def defaults
    KEYS.index_with do |key|
      I18n.t(
        "ibsoft_external_messaging.order_updates.defaults.messages.#{key}",
        locale: locale,
        reference_id: PLACEHOLDER
      )
    end
  end

  def effective
    defaults.merge(endpoint.order_update_messages.to_h.stringify_keys.slice(*KEYS))
  end

  def render(key:, reference_id:)
    effective.fetch(key.to_s).gsub(PLACEHOLDER, reference_id.to_s)
  end

  private

  attr_reader :endpoint

  def locale
    endpoint.account.locale.presence || I18n.default_locale
  end
end

class Ibsoft::ExternalMessaging::OrderUpdateEventKey
  class << self
    def call(order_status:, payment_status:)
      return 'captured_and_completed' if payment_status == 'captured' && order_status == 'completed'
      return "payment_#{payment_status}" if payment_status.present?

      "order_#{order_status}"
    end
  end
end

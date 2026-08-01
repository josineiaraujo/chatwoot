FactoryBot.define do
  factory :ibsoft_external_message_order_update,
          class: 'Ibsoft::ExternalMessaging::OrderUpdate' do
    association :order, factory: :ibsoft_external_message_order
    endpoint { order.opening_delivery.endpoint }
    account { order.account }
    inbox { order.inbox }
    order_status { 'processing' }
    payment_status { nil }
    message_content { "Invoice #{order.reference_id} is processing." }
    description { 'Invoice processing' }
    status { 'queued' }
    source { 'external_api' }
    received_at { Time.current }
  end
end

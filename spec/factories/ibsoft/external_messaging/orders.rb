FactoryBot.define do
  factory :ibsoft_external_message_order,
          class: 'Ibsoft::ExternalMessaging::Order' do
    association :endpoint, factory: :ibsoft_external_message_endpoint
    sequence(:reference_id) { |number| "invoice-#{number}" }
    opening_delivery do
      association(
        :ibsoft_external_message_delivery,
        endpoint: endpoint,
        account: endpoint.account,
        inbox: endpoint.inbox,
        template_type: 'order',
        order_reference_id: reference_id,
        status: 'accepted',
        meta_message_id: "wamid.opening.#{SecureRandom.uuid}"
      )
    end
    account { endpoint.account }
    inbox { endpoint.inbox }
    order_status { 'pending' }
    payment_status { nil }

    after(:build) do |order|
      order.endpoint = order.opening_delivery.endpoint
      order.account = order.endpoint.account
      order.inbox = order.endpoint.inbox
    end

    after(:create) do |order|
      order.opening_delivery.update!(external_order: order)
    end
  end
end

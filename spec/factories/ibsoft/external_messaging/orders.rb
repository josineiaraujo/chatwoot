FactoryBot.define do
  factory :ibsoft_external_message_order,
          class: 'Ibsoft::ExternalMessaging::Order' do
    association :opening_delivery,
                factory: :ibsoft_external_message_delivery,
                template_type: 'order',
                order_reference_id: 'invoice-1',
                status: 'accepted',
                meta_message_id: 'wamid.opening'
    account { opening_delivery.account }
    inbox { opening_delivery.inbox }
    sequence(:reference_id) { |number| "invoice-#{number}" }
    order_status { 'pending' }
    payment_status { nil }
  end
end

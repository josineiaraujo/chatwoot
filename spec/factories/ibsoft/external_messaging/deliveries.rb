FactoryBot.define do
  factory :ibsoft_external_message_delivery,
          class: 'Ibsoft::ExternalMessaging::Delivery' do
    association :endpoint, factory: :ibsoft_external_message_endpoint
    account { endpoint.account }
    inbox { endpoint.inbox }
    sequence(:idempotency_key) { |number| "external-#{number}" }
    request_fingerprint { SecureRandom.hex(32) }
    recipient { '5575982479788' }
    template_name { 'ticket_status_updated' }
    template_language { 'en' }
    template_type { 'standard' }
    template_components { [] }
    message_content { 'Hello customer' }
    status { 'queued' }
    received_at { Time.current }
  end
end

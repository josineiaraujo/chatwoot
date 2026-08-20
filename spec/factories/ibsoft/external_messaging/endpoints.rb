FactoryBot.define do
  factory :ibsoft_external_message_endpoint,
          class: 'Ibsoft::ExternalMessaging::Endpoint' do
    account
    created_by { association(:user, account: account) }
    sequence(:name) { |number| "ERP externo #{number}" }
    token_digest { Ibsoft::ExternalMessaging::Endpoint.digest_token(SecureRandom.hex(32)) }
    token_hint { 'ibext_test...' }
    instance_type { 'sgp_generic' }
    active { true }
    rate_limit_per_second { 10 }
    retention_days { 30 }
    allow_order_resends { true }
    failure_diagnostics_enabled { false }

    transient do
      whatsapp_channel { nil }
    end

    before(:create) do |endpoint, evaluator|
      channel = evaluator.whatsapp_channel || create(
        :channel_whatsapp,
        account: endpoint.account,
        provider: 'whatsapp_cloud',
        sync_templates: false,
        validate_provider_config: false
      )
      endpoint.inbox ||= channel.inbox
    end
  end
end

FactoryBot.define do
  factory :ibsoft_message_broadcast, class: 'Ibsoft::MessageBroadcast::Broadcast' do
    account
    inbox { association :inbox, account: account }
    erp_connection { association :ibsoft_erp_connection, account: account, active: true }
    created_by { association :user, account: account }
    status { 'draft' }
    source_type { 'selection' }
    dispatch_mode { 'bulk' }
    template_name { 'aviso_padrao' }
    template_language { 'pt_BR' }
    conversation_mode { 'direct' }
    template_variables { {} }
  end

  factory :ibsoft_message_broadcast_recipient, class: 'Ibsoft::MessageBroadcast::Recipient' do
    broadcast { create(:ibsoft_message_broadcast) }
    sequence(:external_customer_id) { |n| "cliente-#{n}" }
    customer_name { 'Cliente teste' }
    primary_phone { '+5575982479788' }
    fallback_phone { '+5575999999999' }
    status { 'pending' }
    phone_status { 'pending' }
    template_variable_values { {} }
  end
end

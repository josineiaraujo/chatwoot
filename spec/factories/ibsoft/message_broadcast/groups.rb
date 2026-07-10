FactoryBot.define do
  factory :ibsoft_message_broadcast_group, class: 'Ibsoft::MessageBroadcast::Group' do
    account
    created_by { create(:user, account: account) }
    sequence(:name) { |n| "Grupo #{n}" }
    erp_provider { 'ixc' }
    description { 'Grupo fixo de disparo' }
  end

  factory :ibsoft_message_broadcast_group_member, class: 'Ibsoft::MessageBroadcast::GroupMember' do
    group { create(:ibsoft_message_broadcast_group) }
    sequence(:external_customer_id) { |n| "cliente-#{n}" }
    customer_name { 'Cliente teste' }
    primary_phone { '+5575982479788' }
    fallback_phone { '+5575999999999' }
    city { 'Andarai' }
    state { 'BA' }
    active { true }
  end
end

FactoryBot.define do
  factory :ibsoft_erp_connection, class: 'Ibsoft::Erp::Connection' do
    account
    sequence(:name) { |n| "ERP #{n}" }
    provider { 'ixc' }
    auth_type { 'basic' }
    base_url { 'https://erp.example.com.br' }
    credentials { { username: 'usuario', password: 'senha' } }
    settings { {} }
    active { false }
  end
end

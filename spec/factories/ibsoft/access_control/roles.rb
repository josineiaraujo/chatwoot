FactoryBot.define do
  factory :ibsoft_access_control_role, class: 'Ibsoft::AccessControl::Role' do
    account
    sequence(:name) { |n| "Perfil #{n}" }
    description { 'Perfil operacional' }
    permissions { ['conversation_manage'] }
  end
end

FactoryBot.define do
  factory :ibsoft_access_control_role_assignment, class: 'Ibsoft::AccessControl::RoleAssignment' do
    account
    role { association :ibsoft_access_control_role, account: account }
    user { association :user, account: account }
    created_by { nil }
  end
end

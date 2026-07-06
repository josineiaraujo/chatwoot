FactoryBot.define do
  factory :ibsoft_chathub_account_setting, class: 'Ibsoft::ChathubSettings::AccountSetting' do
    account
    config { {} }
  end
end

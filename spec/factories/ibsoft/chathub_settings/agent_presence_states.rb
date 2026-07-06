FactoryBot.define do
  factory :ibsoft_chathub_agent_presence_state, class: 'Ibsoft::ChathubSettings::AgentPresenceState' do
    account
    user { association :user, account: account }
    current_status { 'offline' }
    last_status_changed_at { Time.current }
    last_online_at { nil }
    last_offline_at { Time.current }
  end
end

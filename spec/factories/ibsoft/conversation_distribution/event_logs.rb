FactoryBot.define do
  factory :ibsoft_distribution_event_log, class: 'Ibsoft::ConversationDistribution::EventLog' do
    account
    inbox { association :inbox, account: account }
    team { association :team, account: account }
    conversation { association :conversation, account: account, inbox: inbox, team: team }
    event_type { 'assignment_completed' }
    reason { 'eligible_for_assignment' }
    metadata { {} }
  end
end

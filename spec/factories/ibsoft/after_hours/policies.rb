FactoryBot.define do
  factory :ibsoft_after_hours_policy, class: 'Ibsoft::AfterHours::Policy' do
    account
    sequence(:name) { |number| "Extra expediente #{number}" }
    enabled { true }
    exit_command { 'sair' }
    regular_message { 'Estamos fora do horario. Digite sair para encerrar.' }
    holiday_message { 'Hoje e feriado. Digite sair para encerrar.' }
    exit_confirmation_message { 'Atendimento encerrado. Voce pode iniciar outro contato quando desejar.' }
  end

  factory :ibsoft_after_hours_wait, class: 'Ibsoft::AfterHours::Wait' do
    account
    after_hours_policy { association :ibsoft_after_hours_policy, account: account }
    team { association :team, account: account }
    conversation { association :conversation, account: account, team: team }
    status { 'active' }
    cause { 'schedule' }
    started_at { Time.current }
  end
end

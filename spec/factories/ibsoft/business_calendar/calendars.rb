FactoryBot.define do
  factory :ibsoft_business_calendar, class: 'Ibsoft::BusinessCalendar::Calendar' do
    account
    sequence(:name) { |number| "Calendario #{number}" }
  end

  factory :ibsoft_business_holiday, class: 'Ibsoft::BusinessCalendar::Holiday' do
    association :business_calendar, factory: :ibsoft_business_calendar
    sequence(:holiday_date) { |number| Date.new(2026, 1, 1) + number.days }
    sequence(:name) { |number| "Feriado #{number}" }
    holiday_kind { 'holiday' }
    source { 'manual' }
    source_scope { 'manual' }
    state_code { nil }
  end

  factory :ibsoft_business_calendar_team_link, class: 'Ibsoft::BusinessCalendar::TeamLink' do
    account
    team { association :team, account: account }
    business_calendar { association :ibsoft_business_calendar, account: account }
  end
end

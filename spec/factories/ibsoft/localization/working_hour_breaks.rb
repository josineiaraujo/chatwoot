# frozen_string_literal: true

FactoryBot.define do
  factory :ibsoft_working_hour_break, class: 'Ibsoft::Localization::WorkingHourBreak' do
    inbox
    account { inbox.account }
    day_of_week { 1 }
    start_hour { 12 }
    start_minutes { 0 }
    end_hour { 13 }
    end_minutes { 0 }
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::BusinessCalendar::Calendar do
  let(:account) { create(:account) }

  it 'requires a name unique inside the account' do
    create(:ibsoft_business_calendar, account: account, name: 'Feriados operacionais')

    duplicate = build(:ibsoft_business_calendar, account: account, name: 'Feriados operacionais')
    same_name_in_other_account = build(:ibsoft_business_calendar, name: 'Feriados operacionais')

    expect(duplicate).not_to be_valid
    expect(same_name_in_other_account).to be_valid
  end

  it 'returns holidays ordered by date and name in the detailed payload' do
    calendar = create(:ibsoft_business_calendar, account: account)
    later = create(:ibsoft_business_holiday, business_calendar: calendar, holiday_date: Date.new(2026, 12, 25), name: 'Natal')
    first = create(:ibsoft_business_holiday, business_calendar: calendar, holiday_date: Date.new(2026, 1, 1), name: 'Confraternizacao')

    payload = calendar.reload.payload(include_holidays: true)

    expect(payload[:holiday_count]).to eq(2)
    expect(payload[:holidays].pluck(:id)).to eq([first.id, later.id])
  end

  it 'destroys its holidays and links without destroying linked departments' do
    calendar = create(:ibsoft_business_calendar, account: account)
    team = create(:team, account: account)
    holiday = create(:ibsoft_business_holiday, business_calendar: calendar)
    link = create(:ibsoft_business_calendar_team_link, account: account, team: team, business_calendar: calendar)

    calendar.destroy!

    expect(Ibsoft::BusinessCalendar::Holiday.exists?(holiday.id)).to be(false)
    expect(Ibsoft::BusinessCalendar::TeamLink.exists?(link.id)).to be(false)
    expect(Team.exists?(team.id)).to be(true)
  end
end

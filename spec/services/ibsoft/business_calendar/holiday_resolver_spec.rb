require 'rails_helper'

RSpec.describe Ibsoft::BusinessCalendar::HolidayResolver do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:calendar) { create(:ibsoft_business_calendar, account: account) }
  let(:holiday_date) { Date.new(2026, 7, 2) }

  before do
    Rails.cache.clear
  end

  it 'returns a linked holiday using the compact cache payload' do
    create(:ibsoft_business_calendar_team_link, account: account, team: team, business_calendar: calendar)
    holiday = create(
      :ibsoft_business_holiday,
      business_calendar: calendar,
      holiday_date: holiday_date,
      name: 'Independencia da Bahia'
    )

    result = described_class.new(account: account, team: team, date: holiday_date).perform

    expect(result).to include(
      id: holiday.id,
      business_calendar_id: calendar.id,
      holiday_date: '2026-07-02',
      name: 'Independencia da Bahia'
    )
  end

  it 'returns nil when the department has no calendar' do
    result = described_class.new(account: account, team: team, date: holiday_date).perform

    expect(result).to be_nil
  end

  it 'does not resolve a calendar linked in another account' do
    other_account = create(:account)
    other_team = create(:team, account: other_account)
    create(
      :ibsoft_business_calendar_team_link,
      account: other_account,
      team: other_team,
      business_calendar: create(:ibsoft_business_calendar, account: other_account)
    )

    result = described_class.new(account: account, team: team, date: holiday_date).perform

    expect(result).to be_nil
  end

  it 'invalidates a cached date after a holiday is changed' do
    create(:ibsoft_business_calendar_team_link, account: account, team: team, business_calendar: calendar)
    holiday = create(
      :ibsoft_business_holiday,
      business_calendar: calendar,
      holiday_date: holiday_date,
      name: 'Nome antigo'
    )
    described_class.new(account: account, team: team, date: holiday_date).perform

    holiday.update!(name: 'Nome atualizado')
    result = described_class.new(account: account, team: team, date: holiday_date).perform

    expect(result[:name]).to eq('Nome atualizado')
  end

  it 'invalidates both dates when a holiday is moved' do
    new_date = holiday_date + 1.day
    create(:ibsoft_business_calendar_team_link, account: account, team: team, business_calendar: calendar)
    holiday = create(
      :ibsoft_business_holiday,
      business_calendar: calendar,
      holiday_date: holiday_date
    )
    described_class.new(account: account, team: team, date: holiday_date).perform

    holiday.update!(holiday_date: new_date)

    expect(described_class.new(account: account, team: team, date: holiday_date).perform).to be_nil
    expect(described_class.new(account: account, team: team, date: new_date).perform).to include(id: holiday.id)
  end
end

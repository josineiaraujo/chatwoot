require 'rails_helper'

RSpec.describe Ibsoft::BusinessCalendar::Holiday do
  let(:calendar) { create(:ibsoft_business_calendar) }

  it 'accepts the supported holiday kinds, sources and scopes' do
    holiday = build(
      :ibsoft_business_holiday,
      business_calendar: calendar,
      holiday_kind: 'optional',
      source: 'invertexto',
      source_scope: 'state',
      state_code: 'BA'
    )

    expect(holiday).to be_valid
  end

  it 'requires a date and a name' do
    holiday = build(:ibsoft_business_holiday, business_calendar: calendar, holiday_date: nil, name: nil)

    expect(holiday).not_to be_valid
    expect(holiday.errors.attribute_names).to include(:holiday_date, :name)
  end

  it 'rejects unsupported kinds, sources and scopes' do
    holiday = build(
      :ibsoft_business_holiday,
      business_calendar: calendar,
      holiday_kind: 'vacation',
      source: 'unknown',
      source_scope: 'municipal'
    )

    expect(holiday).not_to be_valid
    expect(holiday.errors.attribute_names).to include(:holiday_kind, :source, :source_scope)
  end

  it 'accepts only uppercase two-letter state codes' do
    holiday = build(:ibsoft_business_holiday, business_calendar: calendar, state_code: 'ba')

    expect(holiday).not_to be_valid
    expect(holiday.errors.attribute_names).to include(:state_code)
  end

  it 'does not require a state code for national or manual dates' do
    holiday = build(:ibsoft_business_holiday, business_calendar: calendar, state_code: nil)

    expect(holiday).to be_valid
  end

  it 'prevents duplicate dates in the same calendar' do
    existing = create(:ibsoft_business_holiday, business_calendar: calendar)
    duplicate = build(
      :ibsoft_business_holiday,
      business_calendar: calendar,
      holiday_date: existing.holiday_date
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors.attribute_names).to include(:holiday_date)
  end

  it 'allows the same date in different account calendars' do
    existing = create(:ibsoft_business_holiday, business_calendar: calendar)
    other_calendar = create(:ibsoft_business_calendar)
    holiday = build(
      :ibsoft_business_holiday,
      business_calendar: other_calendar,
      holiday_date: existing.holiday_date
    )

    expect(holiday).to be_valid
  end

  it 'invalidates the date cache after creation' do
    holiday = build(:ibsoft_business_holiday, business_calendar: calendar)
    allow(Ibsoft::BusinessCalendar::Cache).to receive(:invalidate_holiday)

    holiday.save!

    expect(Ibsoft::BusinessCalendar::Cache).to have_received(:invalidate_holiday)
      .with(calendar.id, holiday.holiday_date)
  end

  it 'invalidates both dates after moving a holiday' do
    holiday = create(:ibsoft_business_holiday, business_calendar: calendar)
    old_date = holiday.holiday_date
    new_date = old_date + 10.days
    allow(Ibsoft::BusinessCalendar::Cache).to receive(:invalidate_holiday)

    holiday.update!(holiday_date: new_date)

    expect(Ibsoft::BusinessCalendar::Cache).to have_received(:invalidate_holiday).with(calendar.id, old_date)
    expect(Ibsoft::BusinessCalendar::Cache).to have_received(:invalidate_holiday).with(calendar.id, new_date)
  end

  it 'invalidates the date cache after deletion' do
    holiday = create(:ibsoft_business_holiday, business_calendar: calendar)
    date = holiday.holiday_date
    allow(Ibsoft::BusinessCalendar::Cache).to receive(:invalidate_holiday)

    holiday.destroy!

    expect(Ibsoft::BusinessCalendar::Cache).to have_received(:invalidate_holiday).with(calendar.id, date)
  end
end

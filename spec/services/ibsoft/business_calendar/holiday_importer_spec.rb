require 'rails_helper'

RSpec.describe Ibsoft::BusinessCalendar::HolidayImporter do
  let(:calendar) { create(:ibsoft_business_calendar) }
  let(:client) { instance_double(Ibsoft::BusinessCalendar::InvertextoClient) }
  let(:api_holidays) do
    [
      { date: '2026-01-01', name: 'Confraternizacao Universal', type: 'feriado', level: 'nacional' },
      { date: '2026-07-02', name: 'Independencia da Bahia', type: 'feriado', level: 'estadual' },
      { date: '2026-06-24', name: 'Sao Joao', type: 'ponto facultativo', level: 'estadual' },
      { date: '2026-08-15', name: 'Feriado municipal', type: 'feriado', level: 'municipal' }
    ]
  end

  before do
    allow(client).to receive(:holidays).and_return(api_holidays)
  end

  it 'imports only national and selected-state holidays and excludes optional dates by default' do
    result = described_class.new(
      calendar: calendar,
      year: 2026,
      import_options: { state_code: 'BA' },
      client: client
    ).import

    expect(result[:imported].pluck(:name)).to contain_exactly(
      'Confraternizacao Universal',
      'Independencia da Bahia'
    )
    expect(calendar.holidays.pluck(:name)).not_to include('Feriado municipal', 'Sao Joao')
    expect(calendar.holidays.find_by!(name: 'Independencia da Bahia')).to have_attributes(
      source: 'invertexto',
      source_scope: 'state',
      state_code: 'BA'
    )
  end

  it 'can include optional dates explicitly' do
    described_class.new(
      calendar: calendar,
      year: 2026,
      import_options: { state_code: 'BA', include_optional: true },
      client: client
    ).import

    expect(calendar.holidays.find_by!(name: 'Sao Joao').holiday_kind).to eq('optional')
  end

  it 'imports only dates selected from the normalized API response' do
    result = described_class.new(
      calendar: calendar,
      year: 2026,
      import_options: { state_code: 'BA', holiday_dates: ['2026-07-02'] },
      client: client
    ).import

    expect(result[:imported].pluck(:name)).to eq(['Independencia da Bahia'])
    expect(calendar.holidays.pluck(:name)).to eq(['Independencia da Bahia'])
  end

  it 'ignores a selected date that is not present in the normalized API response' do
    result = described_class.new(
      calendar: calendar,
      year: 2026,
      import_options: { state_code: 'BA', holiday_dates: ['2026-12-31'] },
      client: client
    ).import

    expect(result[:imported]).to be_empty
    expect(calendar.holidays).to be_empty
  end

  it 'rejects invalid selected holiday dates before making a request' do
    expect do
      described_class.new(
        calendar: calendar,
        year: 2026,
        import_options: { holiday_dates: ['02/07/2026'] },
        client: client
      )
    end.to raise_error(ArgumentError, 'invalid_holiday_date')

    expect(client).not_to have_received(:holidays)
  end

  it 'does not import state dates when no state was selected' do
    described_class.new(calendar: calendar, year: 2026, client: client).import

    expect(calendar.holidays.pluck(:name)).to contain_exactly('Confraternizacao Universal')
  end

  it 'preserves a manually maintained holiday on the same date' do
    manual_holiday = create(
      :ibsoft_business_holiday,
      business_calendar: calendar,
      holiday_date: Date.new(2026, 1, 1),
      name: 'Nome operacional'
    )

    result = described_class.new(
      calendar: calendar,
      year: 2026,
      import_options: { state_code: 'BA' },
      client: client
    ).import

    expect(result[:skipped].pluck(:id)).to include(manual_holiday.id)
    expect(manual_holiday.reload).to have_attributes(name: 'Nome operacional', source: 'manual')
  end

  it 'rejects unknown state codes before making a request' do
    expect do
      described_class.new(
        calendar: calendar,
        year: 2026,
        import_options: { state_code: 'XX' },
        client: client
      )
    end.to raise_error(ArgumentError, 'invalid_state_code')

    expect(client).not_to have_received(:holidays)
  end
end

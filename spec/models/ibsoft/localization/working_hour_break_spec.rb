# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ibsoft::Localization::WorkingHourBreak do
  let(:inbox) { create(:inbox, timezone: 'America/Sao_Paulo') }

  it 'rejects breaks that end before they start' do
    working_hour_break = build(
      :ibsoft_working_hour_break,
      inbox: inbox,
      start_hour: 14,
      end_hour: 13
    )

    expect(working_hour_break).to be_invalid
    expect(working_hour_break.errors[:end_hour]).to include(
      I18n.t('ibsoft_localization.working_hour_break.errors.end_after_start')
    )
  end

  it 'keeps the inbox closed while inside a configured break' do
    Time.zone = 'America/Sao_Paulo'
    working_hour = inbox.working_hours.find_by(day_of_week: 1)
    working_hour.update!(
      open_hour: 9,
      open_minutes: 0,
      close_hour: 17,
      close_minutes: 0
    )
    create(:ibsoft_working_hour_break, inbox: inbox, day_of_week: 1)

    travel_to Time.zone.parse('2026-06-29 12:30') do
      expect(working_hour.reload.open_at?(Time.zone.now)).to be false
    end

    travel_to Time.zone.parse('2026-06-29 11:30') do
      expect(working_hour.reload.open_at?(Time.zone.now)).to be true
    end
  end

  it 'invalidates the inbox cache when breaks are updated' do
    allow(inbox).to receive(:update_account_cache)

    inbox.update_ibsoft_working_hour_breaks(
      [
        {
          'day_of_week' => 1,
          'start_hour' => 12,
          'start_minutes' => 0,
          'end_hour' => 13,
          'end_minutes' => 0
        }
      ]
    )

    expect(inbox).to have_received(:update_account_cache)
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::BusinessHoursEvaluator do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, timezone: 'America/Sao_Paulo') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  describe '#open?' do
    it 'is always open when the policy ignores business hours' do
      inbox.update!(working_hours_enabled: true)
      allow(inbox).to receive(:working_now?).and_return(false)

      result = described_class.new(
        conversation: conversation,
        config: { mode: 'always_available' }
      ).open?

      expect(result).to be(true)
    end

    it 'inherits the channel business-hours result when no custom mode is configured' do
      inbox.update!(working_hours_enabled: true)
      allow(inbox).to receive(:working_now?).and_return(false)

      result = described_class.new(conversation: conversation, config: {}).open?

      expect(result).to be(false)
    end

    it 'is open when inherited business hours are disabled on the channel' do
      inbox.update!(working_hours_enabled: false)

      result = described_class.new(conversation: conversation, config: {}).open?

      expect(result).to be(true)
    end

    it 'uses the configured timezone instead of the channel timezone' do
      config = custom_config(timezone: 'America/Manaus')
      now = Time.utc(2026, 8, 24, 13, 30) # 09:30 in Manaus and 10:30 in Brasilia

      result = described_class.new(conversation: conversation, config: config, now: now).open?

      expect(result).to be(true)
    end

    it 'falls back to the channel timezone when the configured timezone is invalid' do
      config = custom_config(timezone: 'Invalid/Timezone')
      now = Time.utc(2026, 8, 24, 12, 30) # 09:30 in Brasilia

      result = described_class.new(conversation: conversation, config: config, now: now).open?

      expect(result).to be(true)
    end

    it 'opens exactly at the configured opening time' do
      now = Time.utc(2026, 8, 24, 12, 0) # 09:00 in Brasilia

      result = described_class.new(conversation: conversation, config: custom_config, now: now).open?

      expect(result).to be(true)
    end

    it 'is closed immediately before the configured opening time' do
      now = Time.utc(2026, 8, 24, 11, 59, 59)

      result = described_class.new(conversation: conversation, config: custom_config, now: now).open?

      expect(result).to be(false)
    end

    it 'remains open exactly at the configured closing time, matching the Chatwoot schedule contract' do
      now = Time.utc(2026, 8, 24, 21, 0) # 18:00 in Brasilia

      result = described_class.new(conversation: conversation, config: custom_config, now: now).open?

      expect(result).to be(true)
    end

    it 'is closed immediately after the configured closing time' do
      now = Time.utc(2026, 8, 24, 21, 0, 1)

      result = described_class.new(conversation: conversation, config: custom_config, now: now).open?

      expect(result).to be(false)
    end

    it 'is closed at the beginning of a configured break' do
      now = Time.utc(2026, 8, 24, 15, 0) # 12:00 in Brasilia

      result = described_class.new(conversation: conversation, config: custom_config, now: now).open?

      expect(result).to be(false)
    end

    it 'opens again exactly at the end of a configured break' do
      now = Time.utc(2026, 8, 24, 16, 0) # 13:00 in Brasilia

      result = described_class.new(conversation: conversation, config: custom_config, now: now).open?

      expect(result).to be(true)
    end

    it 'is closed when any of multiple breaks contains the current time' do
      config = custom_config.merge(
        breaks: [
          { day_of_week: 1, start_hour: 10, start_minutes: 0, end_hour: 10, end_minutes: 15 },
          { day_of_week: 1, start_hour: 15, start_minutes: 0, end_hour: 15, end_minutes: 30 }
        ]
      )
      now = Time.utc(2026, 8, 24, 18, 10) # 15:10 in Brasilia

      result = described_class.new(conversation: conversation, config: config, now: now).open?

      expect(result).to be(false)
    end

    it 'keeps an all-day schedule open outside its breaks' do
      config = custom_config.merge(
        schedule: [{ day_of_week: 1, open_all_day: true, closed_all_day: false }]
      )
      now = Time.utc(2026, 8, 24, 7, 0) # 04:00 in Brasilia

      result = described_class.new(conversation: conversation, config: config, now: now).open?

      expect(result).to be(true)
    end

    it 'applies breaks to an all-day schedule' do
      config = custom_config.merge(
        schedule: [{ day_of_week: 1, open_all_day: true, closed_all_day: false }]
      )
      now = Time.utc(2026, 8, 24, 15, 30) # 12:30 in Brasilia

      result = described_class.new(conversation: conversation, config: config, now: now).open?

      expect(result).to be(false)
    end

    it 'keeps a closed-all-day schedule closed' do
      config = custom_config.merge(
        schedule: [{ day_of_week: 1, open_all_day: false, closed_all_day: true }]
      )
      now = Time.utc(2026, 8, 24, 15, 30)

      result = described_class.new(conversation: conversation, config: config, now: now).open?

      expect(result).to be(false)
    end
  end

  def custom_config(timezone: 'America/Sao_Paulo')
    {
      mode: 'custom',
      timezone: timezone,
      schedule: [
        {
          day_of_week: 1,
          open_hour: 9,
          open_minutes: 0,
          close_hour: 18,
          close_minutes: 0,
          open_all_day: false,
          closed_all_day: false
        }
      ],
      breaks: [
        { day_of_week: 1, start_hour: 12, start_minutes: 0, end_hour: 13, end_minutes: 0 }
      ]
    }
  end
end

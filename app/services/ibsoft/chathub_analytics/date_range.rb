class Ibsoft::ChathubAnalytics::DateRange
  DEFAULT_PERIOD = 'last_7_days'.freeze
  PERIODS = %w[last_7_days last_30_days custom].freeze

  def initialize(filters = {})
    @filters = filters.to_h.deep_stringify_keys
  end

  def period
    PERIODS.include?(filters['period']) ? filters['period'] : DEFAULT_PERIOD
  end

  def starts_at
    @starts_at ||= resolve_starts_at
  end

  def ends_at
    @ends_at ||= resolve_ends_at
  end

  def range
    starts_at..ends_at
  end

  def payload
    {
      period: period,
      starts_at: starts_at.iso8601,
      ends_at: ends_at.iso8601
    }
  end

  private

  attr_reader :filters

  def resolve_starts_at
    return custom_starts_at if period == 'custom'
    return 29.days.ago.beginning_of_day if period == 'last_30_days'

    6.days.ago.beginning_of_day
  end

  def resolve_ends_at
    return custom_ends_at if period == 'custom'

    Time.current.end_of_day
  end

  def custom_starts_at
    parsed_time(filters['since'])&.beginning_of_day || 6.days.ago.beginning_of_day
  end

  def custom_ends_at
    parsed_time(filters['until'])&.end_of_day || Time.current.end_of_day
  end

  def parsed_time(value)
    return if value.blank?

    Time.zone.parse(value)
  rescue ArgumentError, TypeError
    nil
  end
end

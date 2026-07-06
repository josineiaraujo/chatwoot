class Ibsoft::ConversationDistribution::BusinessHoursBreakValidator
  DAY_RANGE = (0..6)
  HOUR_RANGE = (0..23)
  MINUTE_RANGE = (0..59)
  TIME_KEYS = %w[start_hour start_minutes end_hour end_minutes].freeze

  def initialize(record, config)
    @record = record
    @config = config
  end

  def validate
    breaks = config.dig('business_hours', 'breaks')
    return if breaks.blank?
    return add_error('business_hours.breaks must be an array') unless breaks.is_a?(Array)

    breaks.each { |break_config| validate_break(break_config) }
  end

  private

  attr_reader :record, :config

  def validate_break(break_config)
    unless break_config.respond_to?(:to_h)
      add_error('business_hours.breaks item must be an object')
      return
    end

    break_config = break_config.to_h.deep_stringify_keys
    validate_day_index(break_config)
    validate_window(break_config)
  end

  def validate_day_index(break_config)
    day = break_config['day_of_week']
    return if integer_string?(day) && DAY_RANGE.cover?(day.to_i)

    add_error('business_hours.breaks.day_of_week must be between 0 and 6')
  end

  def validate_window(break_config)
    return unless time_values_present?(break_config)
    return unless time_values_valid?(break_config)
    return if start_minutes(break_config) < end_minutes(break_config)

    add_error('business_hours.breaks end time must be after start time')
  end

  def time_values_present?(break_config)
    return true if TIME_KEYS.all? { |key| break_config[key].present? }

    add_error('business_hours.breaks must include start and end times')
    false
  end

  def time_values_valid?(break_config)
    return false unless time_values_numeric?(break_config)

    valid = HOUR_RANGE.cover?(break_config['start_hour'].to_i) &&
            HOUR_RANGE.cover?(break_config['end_hour'].to_i) &&
            MINUTE_RANGE.cover?(break_config['start_minutes'].to_i) &&
            MINUTE_RANGE.cover?(break_config['end_minutes'].to_i)
    return true if valid

    add_error('business_hours.breaks has invalid time values')
    false
  end

  def time_values_numeric?(break_config)
    return true if TIME_KEYS.all? { |key| integer_string?(break_config[key]) }

    add_error('business_hours.breaks has invalid time values')
    false
  end

  def start_minutes(break_config)
    (break_config['start_hour'].to_i * 60) + break_config['start_minutes'].to_i
  end

  def end_minutes(break_config)
    (break_config['end_hour'].to_i * 60) + break_config['end_minutes'].to_i
  end

  def integer_string?(value)
    value.to_s.match?(/\A\d+\z/)
  end

  def add_error(message)
    record.errors.add(:config, message)
  end
end

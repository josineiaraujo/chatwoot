class Ibsoft::ConversationDistribution::ConfigurationValidator
  ASSIGNMENT_ORDERS = %w[round_robin balanced].freeze
  ASSIGNMENT_LIMIT_MODES = %w[open_conversations assignment_window].freeze
  CONVERSATION_PRIORITIES = %w[earliest_created longest_waiting].freeze
  BUSINESS_HOURS_MODES = %w[inherit_channel custom always_available].freeze
  BUSINESS_HOURS_DAY_RANGE = (0..6)
  BUSINESS_HOURS_HOUR_RANGE = (0..23)
  BUSINESS_HOURS_MINUTE_RANGE = (0..59)

  def initialize(record)
    @record = record
    @config = record.config
  end

  def validate
    Ibsoft::ConversationDistribution::UnavailabilityConfigValidator.new(record, config).validate
    validate_business_hours_mode
    validate_custom_business_hours
    validate_assignment_order
    validate_assignment_limit_mode
    validate_assignment_confirmation
    validate_capacity_excluded_labels
    validate_conversation_priority
    validate_positive_integer('distribution', 'max_assignments_per_round')
    validate_positive_integer('distribution', 'open_conversation_limit')
    validate_positive_integer('distribution', 'capacity_ignore_customer_waiting_minutes')
    validate_positive_integer('distribution', 'fair_distribution_limit')
    validate_positive_integer('distribution', 'fair_distribution_window')
    validate_positive_integer('redistribution', 'first_response_timeout_minutes')
    validate_positive_integer('supervisor_alert', 'threshold_minutes')
  end

  private

  attr_reader :record, :config

  def validate_business_hours_mode
    mode = config.dig('business_hours', 'mode')
    return if BUSINESS_HOURS_MODES.include?(mode)

    add_error('has invalid business hours mode')
  end

  def validate_assignment_order
    assignment_order = config.dig('distribution', 'assignment_order')
    return if ASSIGNMENT_ORDERS.include?(assignment_order)

    add_error('distribution.assignment_order is invalid')
  end

  def validate_assignment_limit_mode
    assignment_limit_mode = config.dig('distribution', 'assignment_limit_mode')
    return if ASSIGNMENT_LIMIT_MODES.include?(assignment_limit_mode)

    add_error('distribution.assignment_limit_mode is invalid')
  end

  def validate_assignment_confirmation
    return unless boolean_value(config.dig('assignment_confirmation', 'enabled'))
    return if config.dig('assignment_confirmation', 'message').present?

    add_error('assignment_confirmation.message is required when enabled')
  end

  def validate_capacity_excluded_labels
    labels = config.dig('distribution', 'capacity_excluded_labels')
    return if labels.blank?
    return if labels.is_a?(Array) && labels.all?(String)

    add_error('distribution.capacity_excluded_labels must be an array of labels')
  end

  def validate_conversation_priority
    conversation_priority = config.dig('distribution', 'conversation_priority')
    return if CONVERSATION_PRIORITIES.include?(conversation_priority)

    add_error('distribution.conversation_priority is invalid')
  end

  def validate_custom_business_hours
    return unless config.dig('business_hours', 'mode') == 'custom'

    validate_custom_timezone
    validate_custom_schedule
    Ibsoft::ConversationDistribution::BusinessHoursBreakValidator.new(record, config).validate
  end

  def validate_custom_timezone
    timezone = config.dig('business_hours', 'timezone')
    return if timezone.present? && ActiveSupport::TimeZone[timezone].present?

    add_error('business_hours.timezone must be valid')
  end

  def validate_custom_schedule
    schedule = config.dig('business_hours', 'schedule')
    return add_error('business_hours.schedule must be present') if schedule.blank?
    return add_error('business_hours.schedule must be an array') unless schedule.is_a?(Array)

    schedule.each { |day_config| validate_custom_schedule_day(day_config) }
  end

  def validate_custom_schedule_day(day_config)
    unless day_config.respond_to?(:to_h)
      add_error('business_hours.schedule day must be an object')
      return
    end

    day_config = day_config.to_h.deep_stringify_keys
    validate_schedule_day_index(day_config)
    validate_schedule_day_flags(day_config)
    return if boolean_value(day_config['closed_all_day'])
    return if boolean_value(day_config['open_all_day'])

    validate_schedule_day_window(day_config)
  end

  def validate_schedule_day_index(day_config)
    day = day_config['day_of_week']
    return if integer_string?(day) && BUSINESS_HOURS_DAY_RANGE.cover?(day.to_i)

    add_error('business_hours.schedule.day_of_week must be between 0 and 6')
  end

  def validate_schedule_day_flags(day_config)
    closed_all_day = boolean_value(day_config['closed_all_day'])
    open_all_day = boolean_value(day_config['open_all_day'])
    return unless closed_all_day && open_all_day

    add_error('business_hours.schedule cannot be closed and open all day')
  end

  def validate_schedule_day_window(day_config)
    return unless schedule_time_values_present?(day_config)
    return unless schedule_time_values_valid?(day_config)
    return if schedule_start_minutes(day_config) < schedule_end_minutes(day_config)

    add_error('business_hours.schedule close time must be after open time')
  end

  def schedule_time_values_present?(day_config)
    required_keys = %w[open_hour open_minutes close_hour close_minutes]
    return true if required_keys.all? { |key| day_config[key].present? }

    add_error('business_hours.schedule must include open and close times')
    false
  end

  def schedule_time_values_valid?(day_config)
    return false unless schedule_time_values_numeric?(day_config)

    valid = BUSINESS_HOURS_HOUR_RANGE.cover?(day_config['open_hour'].to_i) &&
            BUSINESS_HOURS_HOUR_RANGE.cover?(day_config['close_hour'].to_i) &&
            BUSINESS_HOURS_MINUTE_RANGE.cover?(day_config['open_minutes'].to_i) &&
            BUSINESS_HOURS_MINUTE_RANGE.cover?(day_config['close_minutes'].to_i)
    return true if valid

    add_error('business_hours.schedule has invalid time values')
    false
  end

  def schedule_time_values_numeric?(day_config)
    valid = %w[open_hour open_minutes close_hour close_minutes].all? do |key|
      integer_string?(day_config[key])
    end
    return true if valid

    add_error('business_hours.schedule has invalid time values')
    false
  end

  def validate_positive_integer(section, key)
    value = config.dig(section, key)
    return if value.blank?
    return if value.is_a?(Integer) && value.positive?

    add_error("#{section}.#{key} must be a positive integer")
  end

  def schedule_start_minutes(day_config)
    (day_config['open_hour'].to_i * 60) + day_config['open_minutes'].to_i
  end

  def schedule_end_minutes(day_config)
    (day_config['close_hour'].to_i * 60) + day_config['close_minutes'].to_i
  end

  def boolean_value(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def integer_string?(value)
    value.to_s.match?(/\A\d+\z/)
  end

  def add_error(message)
    record.errors.add(:config, message)
  end
end

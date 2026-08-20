class Ibsoft::ConversationDistribution::BusinessHoursEvaluator
  def initialize(conversation:, config:, now: Time.current)
    @conversation = conversation
    @config = (config || {}).deep_stringify_keys
    @now = now
  end

  def open?
    case config['mode']
    when 'always_available'
      true
    when 'custom'
      custom_schedule_open?
    else
      inbox_working_now?
    end
  end

  def local_now
    @local_now ||= now.in_time_zone(custom_timezone)
  end

  private

  attr_reader :conversation, :config, :now

  def inbox_working_now?
    return true unless conversation.inbox.working_hours_enabled?

    conversation.inbox.working_now?
  end

  def custom_schedule_open?
    return true if custom_schedule.blank?

    working_day = custom_schedule_day
    return true if working_day.blank?
    return false if working_day_closed?(working_day)
    return !inside_custom_break? if working_day_open_all_day?(working_day)
    return true unless working_day_values_present?(working_day)

    inside_working_day_window?(working_day) && !inside_custom_break?
  end

  def custom_schedule_day
    custom_schedule.find { |item| item['day_of_week'].to_i == local_now.wday }
  end

  def working_day_closed?(working_day)
    ActiveModel::Type::Boolean.new.cast(working_day['closed_all_day'])
  end

  def working_day_open_all_day?(working_day)
    ActiveModel::Type::Boolean.new.cast(working_day['open_all_day'])
  end

  def inside_working_day_window?(working_day)
    local_now.between?(day_time(working_day['open_hour'], working_day['open_minutes']),
                       day_time(working_day['close_hour'], working_day['close_minutes']))
  end

  def working_day_values_present?(working_day)
    %w[open_hour open_minutes close_hour close_minutes].all? { |key| working_day[key].present? }
  end

  def day_time(hour, minutes)
    local_now.change(hour: hour.to_i, min: minutes.to_i)
  end

  def custom_timezone
    configured_timezone = config['timezone'].presence
    return conversation.inbox.timezone if configured_timezone.blank?

    ActiveSupport::TimeZone[configured_timezone].presence || conversation.inbox.timezone
  end

  def custom_schedule
    Array(config['schedule']).map(&:stringify_keys)
  end

  def inside_custom_break?
    custom_breaks
      .select { |item| item['day_of_week'].to_i == local_now.wday }
      .any? { |item| custom_break_contains?(item) }
  end

  def custom_break_contains?(break_config)
    current_minutes = (local_now.hour * 60) + local_now.min
    current_minutes >= break_start_minutes(break_config) && current_minutes < break_end_minutes(break_config)
  end

  def break_start_minutes(break_config)
    (break_config['start_hour'].to_i * 60) + break_config['start_minutes'].to_i
  end

  def break_end_minutes(break_config)
    (break_config['end_hour'].to_i * 60) + break_config['end_minutes'].to_i
  end

  def custom_breaks
    Array(config['breaks']).map(&:stringify_keys)
  end
end

class Ibsoft::ChathubSettings::ConfigurationValidator
  PERCENTAGE_RANGE = 0..100

  def initialize(setting)
    @setting = setting
  end

  def validate
    validate_agent_entry_assignment
    validate_login_stabilization
  end

  private

  attr_reader :setting

  def config
    setting.effective_config
  end

  def validate_agent_entry_assignment
    section = config.fetch('agent_entry_assignment')
    validate_percentage(section['required_percentage'], 'agent_entry_assignment.required_percentage')
    validate_positive_integer(section['minimum_required'], 'agent_entry_assignment.minimum_required')
  end

  def validate_login_stabilization
    section = config.fetch('login_stabilization')
    validate_positive_integer(section['offline_threshold_minutes'], 'login_stabilization.offline_threshold_minutes')
    validate_positive_integer(section['window_minutes'], 'login_stabilization.window_minutes')
    validate_positive_integer(section['max_assignments_during_window'], 'login_stabilization.max_assignments_during_window')
    validate_positive_integer(section['minimum_online_agents_to_disable'], 'login_stabilization.minimum_online_agents_to_disable')
  end

  def validate_percentage(value, field)
    return if PERCENTAGE_RANGE.cover?(value.to_i)

    add_error(field, 'must be between 0 and 100')
  end

  def validate_positive_integer(value, field)
    return if value.to_i.positive?

    add_error(field, 'must be greater than 0')
  end

  def add_error(field, message)
    setting.errors.add(:config, "#{field} #{message}")
  end
end

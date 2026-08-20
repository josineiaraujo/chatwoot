class Ibsoft::ConversationDistribution::UnavailabilityConfigValidator
  FALLBACK_ACTIONS = %w[wait notify_customer fallback_team].freeze
  OUTSIDE_BUSINESS_HOURS_ACTIONS = (FALLBACK_ACTIONS + %w[after_hours_policy]).freeze
  UNAVAILABILITY_REASONS = %w[no_available_agent outside_business_hours].freeze

  def initialize(record, config)
    @record = record
    @config = config
  end

  def validate
    validate_legacy_unavailable_action
    validate_legacy_unavailable_config
    validate_reason_configs
  end

  private

  attr_reader :record, :config

  def validate_legacy_unavailable_action
    action = config.dig('unavailable', 'action')
    return if FALLBACK_ACTIONS.include?(action)

    add_error('has invalid unavailable action')
  end

  def validate_legacy_unavailable_config
    validate_config('unavailable', config['unavailable'] || {})
  end

  def validate_reason_configs
    UNAVAILABILITY_REASONS.each do |reason|
      validate_config("unavailability.#{reason}", config.dig('unavailability', reason) || {}, reason: reason)
    end
  end

  def validate_config(path, unavailable_config, reason: nil)
    action = unavailable_config['action']
    allowed_actions = reason == 'outside_business_hours' ? OUTSIDE_BUSINESS_HOURS_ACTIONS : FALLBACK_ACTIONS
    return add_error("#{path}.action is invalid") unless allowed_actions.include?(action)

    case action
    when 'notify_customer'
      validate_message(path, unavailable_config)
    when 'fallback_team'
      validate_fallback_team(path, unavailable_config)
    when 'after_hours_policy'
      validate_after_hours_policy(path)
    end
  end

  def validate_message(path, unavailable_config)
    return if unavailable_config['message'].present?

    add_error("#{path}.message is required when action is notify_customer")
  end

  def validate_fallback_team(path, unavailable_config)
    fallback_team_id = unavailable_config['fallback_team_id']
    return add_error("#{path}.fallback_team_id is required") if fallback_team_id.blank?
    return if Team.exists?(id: fallback_team_id, account_id: record.account_id)

    add_error("#{path}.fallback_team_id must belong to account")
  end

  def validate_after_hours_policy(path)
    policy = record.after_hours_policy
    return add_error("#{path}.after_hours_policy_id is required") if policy.blank?
    return if policy.account_id == record.account_id

    add_error("#{path}.after_hours_policy_id must belong to account")
  end

  def add_error(message)
    record.errors.add(:config, message)
  end
end

module Ibsoft::ConversationDistribution::Configuration
  extend ActiveSupport::Concern

  FALLBACK_ACTIONS = %w[wait notify_customer fallback_team].freeze
  BUSINESS_HOURS_MODES = %w[inherit_channel custom always_available].freeze

  DEFAULT_CONFIG = {
    'eligible_sources' => %w[bot_handoff manual_team_transfer system_team_transfer],
    'distribution' => {
      'strategy' => 'round_robin',
      'min_assignments_on_login' => 1,
      'max_assignments_per_round' => 5,
      'assign_all_when_single_agent' => false,
      'capacity_limit' => nil
    },
    'redistribution' => {
      'enabled' => false,
      'first_response_timeout_minutes' => 15
    },
    'unavailable' => {
      'action' => 'wait',
      'message' => nil,
      'fallback_team_id' => nil
    },
    'business_hours' => {
      'mode' => 'inherit_channel',
      'timezone' => nil,
      'schedule' => []
    },
    'supervisor_alert' => {
      'enabled' => false,
      'threshold_minutes' => 30
    }
  }.freeze

  included do
    before_validation :normalize_distribution_config
    validate :validate_distribution_config
  end

  class_methods do
    def default_config
      DEFAULT_CONFIG.deep_dup
    end
  end

  def effective_config
    self.class.default_config.deep_merge(config || {})
  end

  def payload
    {
      id: id,
      account_id: account_id,
      enabled: enabled?,
      config: effective_config,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def normalize_distribution_config
    self.config = self.class.default_config.deep_merge((config || {}).deep_stringify_keys)
  end

  def validate_distribution_config
    validate_unavailable_action
    validate_business_hours_mode
    validate_positive_integer('distribution', 'min_assignments_on_login')
    validate_positive_integer('distribution', 'max_assignments_per_round')
    validate_positive_integer('redistribution', 'first_response_timeout_minutes')
    validate_positive_integer('supervisor_alert', 'threshold_minutes')
  end

  def validate_unavailable_action
    action = config.dig('unavailable', 'action')
    return if FALLBACK_ACTIONS.include?(action)

    errors.add(:config, 'has invalid unavailable action')
  end

  def validate_business_hours_mode
    mode = config.dig('business_hours', 'mode')
    return if BUSINESS_HOURS_MODES.include?(mode)

    errors.add(:config, 'has invalid business hours mode')
  end

  def validate_positive_integer(section, key)
    value = config.dig(section, key)
    return if value.blank?
    return if value.is_a?(Integer) && value.positive?

    errors.add(:config, "#{section}.#{key} must be a positive integer")
  end
end

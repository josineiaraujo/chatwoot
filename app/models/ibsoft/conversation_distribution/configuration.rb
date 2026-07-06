module Ibsoft::ConversationDistribution::Configuration
  extend ActiveSupport::Concern

  DEFAULT_UNAVAILABLE_CONFIG = { 'action' => 'wait', 'message' => nil, 'fallback_team_id' => nil }.freeze

  DISTRIBUTION_CONFIG_KEYS = %w[
    max_assignments_per_round_enabled max_assignments_per_round assignment_order
    conversation_priority assignment_limit_mode open_conversation_limit
    capacity_ignore_customer_waiting_enabled capacity_ignore_customer_waiting_minutes
    capacity_excluded_labels fair_distribution_limit fair_distribution_window
  ].freeze

  DEFAULT_CONFIG = {
    'eligible_sources' => %w[bot_handoff manual_team_transfer system_team_transfer],
    'distribution' => {
      'max_assignments_per_round_enabled' => true,
      'max_assignments_per_round' => 5,
      'assignment_order' => 'round_robin',
      'conversation_priority' => 'longest_waiting',
      'assignment_limit_mode' => 'open_conversations',
      'open_conversation_limit' => 5,
      'capacity_ignore_customer_waiting_enabled' => false,
      'capacity_ignore_customer_waiting_minutes' => 1440,
      'capacity_excluded_labels' => [],
      'fair_distribution_limit' => 100,
      'fair_distribution_window' => 3600
    },
    'redistribution' => { 'enabled' => false, 'first_response_timeout_minutes' => 15 },
    'assignment_confirmation' => {
      'enabled' => false, 'message' => nil, 'only_before_first_reply' => true
    },
    'unavailable' => DEFAULT_UNAVAILABLE_CONFIG,
    'unavailability' => {
      'no_available_agent' => DEFAULT_UNAVAILABLE_CONFIG,
      'outside_business_hours' => DEFAULT_UNAVAILABLE_CONFIG
    },
    'business_hours' => { 'mode' => 'inherit_channel', 'timezone' => nil, 'schedule' => [], 'breaks' => [] },
    'supervisor_alert' => { 'enabled' => false, 'threshold_minutes' => 30 }
  }.freeze

  CONFIG_SECTIONS = {
    'distribution' => DISTRIBUTION_CONFIG_KEYS,
    'redistribution' => %w[enabled first_response_timeout_minutes],
    'assignment_confirmation' => %w[enabled message only_before_first_reply],
    'unavailable' => %w[action message fallback_team_id],
    'unavailability' => %w[no_available_agent outside_business_hours],
    'business_hours' => %w[mode timezone schedule breaks],
    'supervisor_alert' => %w[enabled threshold_minutes]
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
    normalize_unavailability_config(self.class.default_config.deep_merge(sanitized_config(config || {})), config || {})
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
    raw_config = config || {}
    self.config = normalize_unavailability_config(self.class.default_config.deep_merge(sanitized_config(raw_config)), raw_config)
  end

  def validate_distribution_config
    Ibsoft::ConversationDistribution::ConfigurationValidator.new(self).validate
  end

  def sanitized_config(raw_config)
    config_hash = (raw_config || {}).deep_stringify_keys
    sanitized = config_hash.slice('eligible_sources')

    CONFIG_SECTIONS.each_with_object(sanitized) do |(section, keys), memo|
      section_config = config_hash.fetch(section, {}).slice(*keys)
      memo[section] = section_config if section_config.present?
    end
  end

  def normalize_unavailability_config(normalized_config, raw_config)
    Ibsoft::ConversationDistribution::UnavailabilityConfigNormalizer.normalize(
      normalized_config: normalized_config,
      raw_config: raw_config,
      default_unavailable: self.class.default_config['unavailable']
    )
  end
end

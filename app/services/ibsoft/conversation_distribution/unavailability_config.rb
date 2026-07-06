class Ibsoft::ConversationDistribution::UnavailabilityConfig
  DEFAULT_CONFIG = {
    'action' => 'wait',
    'message' => nil,
    'fallback_team_id' => nil
  }.freeze

  def self.for(policy_config, reason)
    new(policy_config, reason).to_h
  end

  def initialize(policy_config, reason)
    @policy_config = (policy_config || {}).deep_stringify_keys
    @reason = reason.to_s
  end

  def to_h
    DEFAULT_CONFIG.deep_merge(reason_config.presence || legacy_config)
  end

  private

  attr_reader :policy_config, :reason

  def reason_config
    policy_config.dig('unavailability', reason)
  end

  def legacy_config
    policy_config['unavailable'] || {}
  end
end

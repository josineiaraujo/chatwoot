class Ibsoft::ConversationDistribution::UnavailabilityConfigNormalizer
  def self.normalize(normalized_config:, raw_config:, default_unavailable:)
    new(
      normalized_config: normalized_config,
      raw_config: raw_config,
      default_unavailable: default_unavailable
    ).perform
  end

  def initialize(normalized_config:, raw_config:, default_unavailable:)
    @normalized_config = normalized_config
    @raw_config = (raw_config || {}).deep_stringify_keys
    @default_unavailable = default_unavailable
  end

  def perform
    return normalized_config.merge('unavailable' => default_unavailable.deep_dup) if raw_config['unavailability'].present?
    return normalized_config unless custom_unavailable_config?

    normalized_config.merge(
      'unavailability' => {
        'no_available_agent' => legacy_config.deep_dup,
        'outside_business_hours' => legacy_config.deep_dup
      }
    )
  end

  private

  attr_reader :normalized_config, :raw_config, :default_unavailable

  def custom_unavailable_config?
    legacy_config.present? &&
      (legacy_config['action'] != 'wait' || legacy_config['message'].present? || legacy_config['fallback_team_id'].present?)
  end

  def legacy_config
    @legacy_config ||= normalized_config['unavailable']
  end
end

class Ibsoft::AfterHours::PolicyDestroyer
  def initialize(policy:)
    @policy = policy
  end

  def perform
    destroyed = false

    ApplicationRecord.transaction do
      policy.lock!
      detach_distribution_policies

      raise ActiveRecord::Rollback unless policy.destroy

      destroyed = true
    end

    destroyed
  end

  private

  attr_reader :policy

  def detach_distribution_policies
    policy.distribution_policies.lock.each do |distribution_policy|
      config = distribution_policy.config.deep_stringify_keys
      reset_outside_business_hours_action(config)
      distribution_policy.update!(config: config, after_hours_policy: nil)
    end
  end

  def reset_outside_business_hours_action(config)
    return unless config.dig('unavailability', 'outside_business_hours', 'action') == 'after_hours_policy'

    config['unavailability']['outside_business_hours'] =
      Ibsoft::ConversationDistribution::Configuration::DEFAULT_UNAVAILABLE_CONFIG.deep_dup
  end
end

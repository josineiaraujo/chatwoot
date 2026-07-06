class Ibsoft::ConversationDistribution::RedistributionPolicy
  def initialize(policy)
    @policy = policy
  end

  def enabled?
    value(:enabled)
  end

  def redistribution_enabled?
    ActiveModel::Type::Boolean.new.cast(redistribution_config['enabled'])
  end

  def timeout_minutes
    redistribution_config['first_response_timeout_minutes'].to_i
  end

  def raw_policy
    policy
  end

  def payload
    {
      id: value(:id),
      source: value(:source),
      policy_type: value(:policy_type),
      enabled: enabled?,
      redistribution_enabled: redistribution_enabled?,
      first_response_timeout_minutes: timeout_minutes,
      business_hours_mode: policy_config.dig('business_hours', 'mode')
    }
  end

  private

  attr_reader :policy

  def value(key)
    return policy[key] if policy.key?(key)

    policy[key.to_s]
  end

  def redistribution_config
    policy_config['redistribution'] || {}
  end

  def policy_config
    value(:config) || {}
  end
end

class Ibsoft::ConversationDistribution::AgentEntryAssignmentPolicy
  def initialize(account:, candidate_count:)
    @account = account
    @candidate_count = candidate_count.to_i
  end

  def enabled?
    ActiveModel::Type::Boolean.new.cast(config['enabled'])
  end

  def required_count
    return 0 unless enabled?
    return 0 unless candidate_count.positive?

    percentage_count.clamp(required_lower_bound, candidate_count)
  end

  def block_close_when_required?
    ActiveModel::Type::Boolean.new.cast(config['block_close_when_required'])
  end

  def payload
    {
      enabled: enabled?,
      required_percentage: required_percentage,
      minimum_required: minimum_required,
      block_close_when_required: block_close_when_required?,
      required_count: required_count
    }
  end

  private

  attr_reader :account, :candidate_count

  def config
    @config ||= Ibsoft::ChathubSettings::SettingsResolver
                .config_for(account)
                .fetch('agent_entry_assignment')
  end

  def percentage_count
    (candidate_count * required_percentage / 100.0).ceil
  end

  def required_percentage
    config['required_percentage'].to_i
  end

  def minimum_required
    positive_integer(config['minimum_required'], 1)
  end

  def required_lower_bound
    [minimum_required, candidate_count].min
  end

  def positive_integer(value, fallback)
    value.to_i.positive? ? value.to_i : fallback
  end
end

class Ibsoft::ConversationDistribution::ExecutionConfig
  REAL_ASSIGNMENT_ENV = 'IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED'.freeze
  JOB_ENABLED_ENV = 'IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED'.freeze
  JOB_LIMIT_ENV = 'IBSOFT_CONVERSATION_DISTRIBUTION_JOB_LIMIT'.freeze

  def self.real_assignment_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(REAL_ASSIGNMENT_ENV, false))
  end

  def self.job_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(JOB_ENABLED_ENV, false))
  end

  def self.job_limit
    requested_limit = ENV.fetch(JOB_LIMIT_ENV, Ibsoft::ConversationDistribution::CandidateFinder::DEFAULT_LIMIT).to_i
    requested_limit = Ibsoft::ConversationDistribution::CandidateFinder::DEFAULT_LIMIT unless requested_limit.positive?

    [requested_limit, Ibsoft::ConversationDistribution::CandidateFinder::MAX_LIMIT].min
  end
end

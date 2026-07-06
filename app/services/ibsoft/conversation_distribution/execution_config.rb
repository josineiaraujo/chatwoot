class Ibsoft::ConversationDistribution::ExecutionConfig
  REAL_ASSIGNMENT_ENV = 'IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED'.freeze
  JOB_ENABLED_ENV = 'IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED'.freeze
  JOB_LIMIT_ENV = 'IBSOFT_CONVERSATION_DISTRIBUTION_JOB_LIMIT'.freeze
  EVENT_DEDUPE_WINDOW_ENV = 'IBSOFT_CONVERSATION_DISTRIBUTION_EVENT_DEDUPE_WINDOW_SECONDS'.freeze
  WATCHDOG_LOCK_TTL_ENV = 'IBSOFT_CONVERSATION_DISTRIBUTION_WATCHDOG_LOCK_TTL_SECONDS'.freeze
  DEFAULT_EVENT_DEDUPE_WINDOW_SECONDS = 15.minutes.to_i
  DEFAULT_WATCHDOG_LOCK_TTL_SECONDS = 5.minutes.to_i

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

  def self.event_dedupe_window
    requested_window = ENV.fetch(EVENT_DEDUPE_WINDOW_ENV, DEFAULT_EVENT_DEDUPE_WINDOW_SECONDS).to_i
    requested_window = DEFAULT_EVENT_DEDUPE_WINDOW_SECONDS if requested_window.negative?

    requested_window.seconds
  end

  def self.watchdog_lock_ttl
    requested_ttl = ENV.fetch(WATCHDOG_LOCK_TTL_ENV, DEFAULT_WATCHDOG_LOCK_TTL_SECONDS).to_i
    requested_ttl = DEFAULT_WATCHDOG_LOCK_TTL_SECONDS unless requested_ttl.positive?

    requested_ttl
  end
end

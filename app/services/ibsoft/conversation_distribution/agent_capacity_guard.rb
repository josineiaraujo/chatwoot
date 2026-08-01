require 'digest'

class Ibsoft::ConversationDistribution::AgentCapacityGuard
  LIMIT_MODE_OPEN_CONVERSATIONS = 'open_conversations'.freeze
  LOCK_NAMESPACE = 'ibsoft:conversation_distribution:agent_capacity'.freeze

  def initialize(account:, agent:, policy:)
    @account = account
    @agent = agent
    @policy = policy
  end

  def perform
    ApplicationRecord.transaction do
      acquire_capacity_lock if enforce_open_conversation_limit?
      next result(:capacity_reached) unless capacity_available?

      assignment = yield
      next result(:candidate_changed) if assignment.blank?

      result(:claimed, assignment)
    end
  end

  private

  attr_reader :account, :agent, :policy

  def capacity_available?
    return true unless enforce_open_conversation_limit?

    Ibsoft::ConversationDistribution::AgentCapacityEvaluator.new(
      account: account,
      agent: agent,
      policy: policy
    ).within_limit?
  end

  def enforce_open_conversation_limit?
    assignment_limit_mode == LIMIT_MODE_OPEN_CONVERSATIONS
  end

  def assignment_limit_mode
    policy.dig(:config, 'distribution', 'assignment_limit_mode').presence || LIMIT_MODE_OPEN_CONVERSATIONS
  end

  # PostgreSQL transaction advisory locks coordinate every Sidekiq process and application instance.
  def acquire_capacity_lock
    connection.execute(
      "SELECT pg_advisory_xact_lock(#{connection.quote(advisory_lock_key)})"
    )
  end

  def advisory_lock_key
    Digest::SHA256
      .digest([LOCK_NAMESPACE, account.id, agent.id].join(':'))
      .unpack1('q>')
  end

  def connection
    ApplicationRecord.connection
  end

  def result(status, assignment = nil)
    { status: status, assignment: assignment }
  end
end

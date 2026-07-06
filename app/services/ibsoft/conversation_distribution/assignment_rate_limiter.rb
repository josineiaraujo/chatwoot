class Ibsoft::ConversationDistribution::AssignmentRateLimiter
  KEY = (
    'IBSOFT_CONVERSATION_DISTRIBUTION::ACCOUNT::%<account_id>d::INBOX::%<inbox_id>d::' \
      'TEAM::%<team_id>s::AGENT::%<agent_id>d::ASSIGNMENTS'
  ).freeze

  def initialize(account:, conversation:, agent:, policy:)
    @account = account
    @conversation = conversation
    @agent = agent
    @policy = policy
  end

  def within_limit?
    current_count < limit
  end

  def track_assignment
    prune_old_assignments
    Redis::Alfred.zadd(assignment_key, current_timestamp, conversation.id)
    Redis::Alfred.expire(assignment_key, window)
  end

  def current_count
    prune_old_assignments
    Redis::Alfred.zcard(assignment_key)
  end

  private

  attr_reader :account, :conversation, :agent, :policy

  def limit
    configured_limit = distribution_config['fair_distribution_limit'].to_i
    configured_limit.positive? ? configured_limit : 100
  end

  def window
    configured_window = distribution_config['fair_distribution_window'].to_i
    configured_window.positive? ? configured_window : 1.hour.to_i
  end

  def distribution_config
    policy.dig(:config, 'distribution') || {}
  end

  def assignment_key
    format(
      KEY,
      account_id: account.id,
      inbox_id: conversation.inbox_id,
      team_id: conversation.team_id || 'none',
      agent_id: agent.id
    )
  end

  def prune_old_assignments
    Redis::Alfred.zremrangebyscore(assignment_key, '-inf', current_timestamp - window)
  end

  def current_timestamp
    Time.current.to_i
  end
end

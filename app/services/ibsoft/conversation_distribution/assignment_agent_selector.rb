class Ibsoft::ConversationDistribution::AssignmentAgentSelector
  ROUND_ROBIN = 'round_robin'.freeze
  BALANCED = 'balanced'.freeze
  LIMIT_MODE_OPEN_CONVERSATIONS = 'open_conversations'.freeze
  LIMIT_MODE_ASSIGNMENT_WINDOW = 'assignment_window'.freeze

  def initialize(account:, conversation:, allowed_agent_ids:, policy:)
    @account = account
    @conversation = conversation
    @allowed_agent_ids = allowed_agent_ids
    @policy = policy
  end

  def perform
    return if capacity_limited_agent_ids.blank?

    assignment_order == BALANCED ? balanced_agent : round_robin_agent(capacity_limited_agent_ids)
  end

  private

  attr_reader :account, :conversation, :allowed_agent_ids, :policy

  def assignment_order
    policy.dig(:config, 'distribution', 'assignment_order').presence || ROUND_ROBIN
  end

  def capacity_limited_agent_ids
    @capacity_limited_agent_ids ||= allowed_online_agent_ids.select do |agent_id|
      agent = agents_by_id[agent_id.to_i]
      agent.present? && assignment_limit_for(agent).within_limit?
    end
  end

  def allowed_online_agent_ids
    @allowed_online_agent_ids ||= online_agent_ids & allowed_agent_ids.map(&:to_s)
  end

  def online_agent_ids
    online_agents = OnlineStatusTracker.get_available_users(account.id)
    return [] if online_agents.blank?

    online_agents.select { |_key, value| value.eql?('online') }.keys
  end

  def agents_by_id
    @agents_by_id ||= User.where(id: allowed_online_agent_ids).index_by(&:id)
  end

  def balanced_agent
    counts = open_assignment_counts
    lowest_count = capacity_limited_agent_ids.map { |agent_id| counts[agent_id.to_i] || 0 }.min
    balanced_agent_ids = capacity_limited_agent_ids.select { |agent_id| (counts[agent_id.to_i] || 0) == lowest_count }

    round_robin_agent(balanced_agent_ids)
  end

  def round_robin_agent(agent_ids)
    AutoAssignment::InboxRoundRobinService
      .new(inbox: conversation.inbox)
      .available_agent(allowed_agent_ids: agent_ids)
  end

  def open_assignment_counts
    scope = account.conversations.open.where(inbox_id: conversation.inbox_id, assignee_id: capacity_limited_agent_ids)
    scope = scope.where(team_id: conversation.team_id) if conversation.team_id.present?

    scope.group(:assignee_id).count
  end

  def assignment_limit_for(agent)
    return rate_limiter_for(agent) if assignment_limit_mode == LIMIT_MODE_ASSIGNMENT_WINDOW

    Ibsoft::ConversationDistribution::AgentCapacityEvaluator.new(
      account: account,
      agent: agent,
      policy: policy
    )
  end

  def assignment_limit_mode
    policy.dig(:config, 'distribution', 'assignment_limit_mode').presence || LIMIT_MODE_OPEN_CONVERSATIONS
  end

  def rate_limiter_for(agent)
    Ibsoft::ConversationDistribution::AssignmentRateLimiter.new(
      account: account,
      conversation: conversation,
      agent: agent,
      policy: policy
    )
  end
end

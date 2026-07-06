class Ibsoft::ConversationDistribution::AgentCapacityEvaluator
  OUTBOUND_MESSAGE_TYPES = %w[outgoing template].freeze

  def initialize(account:, agent:, policy:)
    @account = account
    @agent = agent
    @policy = policy
  end

  def within_limit?
    current_count < open_conversation_limit
  end

  def current_count
    capacity_scope.count
  end

  private

  attr_reader :account, :agent, :policy

  def capacity_scope
    scope = account.conversations.open.where(assignee_id: agent.id)
    scope = without_excluded_labels(scope)
    without_waiting_customer(scope)
  end

  def without_excluded_labels(scope)
    return scope if excluded_labels.blank?

    scope.where.not(
      id: Conversation.tagged_with(excluded_labels, any: true).reselect(:id)
    )
  end

  def without_waiting_customer(scope)
    return scope unless ignore_waiting_customer?

    scope.where.not(id: stale_customer_waiting_conversation_ids(scope))
  end

  def stale_customer_waiting_conversation_ids(scope)
    Message
      .where(id: last_public_message_ids(scope))
      .where(message_type: OUTBOUND_MESSAGE_TYPES)
      .where('created_at <= ?', customer_waiting_cutoff)
      .select(:conversation_id)
  end

  def last_public_message_ids(scope)
    Message
      .chat
      .where(account_id: account.id, conversation_id: scope.select(:id))
      .select('DISTINCT ON (messages.conversation_id) messages.id')
      .reorder('messages.conversation_id ASC, messages.created_at DESC, messages.id DESC')
  end

  def open_conversation_limit
    configured_limit = distribution_config['open_conversation_limit'].to_i
    configured_limit.positive? ? configured_limit : 5
  end

  def excluded_labels
    Array(distribution_config['capacity_excluded_labels']).filter_map do |label|
      label.to_s.strip.presence
    end
  end

  def ignore_waiting_customer?
    ActiveModel::Type::Boolean.new.cast(
      distribution_config['capacity_ignore_customer_waiting_enabled']
    )
  end

  def customer_waiting_cutoff
    customer_waiting_minutes.minutes.ago
  end

  def customer_waiting_minutes
    configured_minutes = distribution_config['capacity_ignore_customer_waiting_minutes'].to_i
    configured_minutes.positive? ? configured_minutes : 1440
  end

  def distribution_config
    policy.dig(:config, 'distribution') || {}
  end
end

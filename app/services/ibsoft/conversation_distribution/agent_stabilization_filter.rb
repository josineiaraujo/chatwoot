class Ibsoft::ConversationDistribution::AgentStabilizationFilter
  COMPLETED_EVENT_TYPES = %w[
    assignment_completed
    redistribution_completed
    agent_claim_completed
  ].freeze

  def initialize(account:, allowed_agent_ids:)
    @account = account
    @allowed_agent_ids = Array(allowed_agent_ids).map(&:to_i)
  end

  def perform
    return allowed_agent_ids unless enabled?
    return allowed_agent_ids if online_allowed_agent_ids.size >= minimum_online_agents_to_disable

    allowed_agent_ids.select { |agent_id| available_during_stabilization?(agent_id) }
  end

  private

  attr_reader :account, :allowed_agent_ids

  def available_during_stabilization?(agent_id)
    return true unless stabilizing?(agent_id)

    assignment_count_during_window(agent_id) < max_assignments_during_window
  end

  def stabilizing?(agent_id)
    state = presence_states_by_user_id[agent_id]
    return false if state.blank? || state.current_status != 'online'
    return false if state.last_online_at.blank? || state.last_offline_at.blank?
    return false if state.last_online_at < window_minutes.minutes.ago

    (state.last_online_at - state.last_offline_at) >= offline_threshold_minutes.minutes
  end

  def assignment_count_during_window(agent_id)
    state = presence_states_by_user_id[agent_id]
    return 0 if state&.last_online_at.blank?

    Ibsoft::ConversationDistribution::EventLog
      .where(account: account, new_assignee_id: agent_id, event_type: COMPLETED_EVENT_TYPES)
      .where('created_at >= ?', state.last_online_at)
      .count
  end

  def presence_states_by_user_id
    @presence_states_by_user_id ||=
      Ibsoft::ChathubSettings::AgentPresenceState
      .where(account: account, user_id: allowed_agent_ids)
      .index_by(&:user_id)
  end

  def online_allowed_agent_ids
    online_user_ids = OnlineStatusTracker
                      .get_available_users(account.id)
                      .select { |_id, status| status == 'online' }
                      .keys
                      .map(&:to_i)

    online_user_ids & allowed_agent_ids
  end

  def config
    @config ||= Ibsoft::ChathubSettings::SettingsResolver
                .config_for(account)
                .fetch('login_stabilization')
  end

  def enabled?
    ActiveModel::Type::Boolean.new.cast(config['enabled'])
  end

  def offline_threshold_minutes
    config['offline_threshold_minutes'].to_i
  end

  def window_minutes
    config['window_minutes'].to_i
  end

  def max_assignments_during_window
    config['max_assignments_during_window'].to_i
  end

  def minimum_online_agents_to_disable
    config['minimum_online_agents_to_disable'].to_i
  end
end

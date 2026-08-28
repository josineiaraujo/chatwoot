class Ibsoft::ConversationDistribution::SupervisorAlertFinder
  DEFAULT_LIMIT = Ibsoft::ConversationDistribution::CandidateFinder::DEFAULT_LIMIT
  MAX_LIMIT = Ibsoft::ConversationDistribution::CandidateFinder::MAX_LIMIT

  def initialize(account:, inbox_id: nil, team_id: nil, limit: DEFAULT_LIMIT)
    @account = account
    @inbox_id = inbox_id
    @team_id = team_id
    @limit = limit
    @policy_cache = {}
  end

  def perform
    alerts = conversations.filter_map { |conversation| alert_for(conversation) }

    {
      generated_at: Time.current.iso8601,
      filters: filters,
      limit: safe_limit,
      summary: summary(alerts),
      alerts: alerts
    }
  end

  private

  attr_reader :account, :inbox_id, :team_id, :limit, :policy_cache

  def conversations
    @conversations ||= begin
      scope = account.conversations
                     .includes(:inbox, :team, :assignee, :contact)
                     .open
                     .where(first_reply_created_at: nil)
                     .where.not(team_id: nil)
                     .where.not(waiting_since: nil)

      scope = scope.where(inbox_id: inbox_id) if inbox_id.present?
      scope = scope.where(team_id: team_id) if team_id.present?

      scope.sort_on_waiting_since.limit(safe_limit).to_a
    end
  end

  def alert_for(conversation)
    policy = effective_policy_for(conversation)
    return unless policy[:enabled]

    alert_config = policy.fetch(:config, {}).deep_stringify_keys.fetch('supervisor_alert', {})
    return unless ActiveModel::Type::Boolean.new.cast(alert_config['enabled'])

    threshold_minutes = normalized_threshold(alert_config)
    wait_started_at = wait_started_at_for(conversation)
    minutes_waiting = minutes_waiting_since(wait_started_at)
    return if minutes_waiting < threshold_minutes

    build_payload(conversation, policy, threshold_minutes, wait_started_at, minutes_waiting)
  end

  def build_payload(conversation, policy, threshold_minutes, wait_started_at, minutes_waiting)
    last_event = last_distribution_event_for(conversation)

    {
      conversation_id: conversation.id,
      display_id: conversation.display_id,
      account_id: conversation.account_id,
      inbox: resource_payload(conversation.inbox),
      team: resource_payload(conversation.team),
      assignee: user_payload(conversation.assignee),
      contact: contact_payload(conversation.contact),
      status: conversation.status,
      reason: alert_reason_for(conversation),
      policy: policy_payload(policy),
      last_distribution_event: event_payload(last_event)
    }.merge(timing_payload(conversation, threshold_minutes, wait_started_at, minutes_waiting))
  end

  def effective_policy_for(conversation)
    key = [conversation.inbox_id, conversation.team_id]
    policy_cache[key] ||= Ibsoft::ConversationDistribution::EffectivePolicyResolver.new(
      account: account,
      inbox: conversation.inbox,
      team: conversation.team
    ).perform
  end

  def normalized_threshold(alert_config)
    threshold = alert_config['threshold_minutes'].to_i
    threshold.positive? ? threshold : Ibsoft::ConversationDistribution::Policy.default_config.dig('supervisor_alert', 'threshold_minutes')
  end

  def wait_started_at_for(conversation)
    last_event = last_distribution_event_for(conversation)
    return last_event.created_at if conversation.assignee_id.present? && last_event.present?

    conversation.waiting_since
  end

  def minutes_waiting_since(time)
    ((Time.current - time) / 60).floor
  end

  def alert_reason_for(conversation)
    return 'assigned_without_first_reply' if conversation.assignee_id.present?

    'unassigned_waiting'
  end

  def last_distribution_event_for(conversation) = latest_distribution_events[conversation.id]

  def latest_distribution_events
    @latest_distribution_events ||= begin
      event_log_class = Ibsoft::ConversationDistribution::EventLog
      table_name = event_log_class.table_name
      order = "#{table_name}.conversation_id ASC, #{table_name}.created_at DESC, #{table_name}.id DESC"
      event_log_class
        .where(account: account, conversation_id: conversations.map(&:id))
        .select("DISTINCT ON (#{table_name}.conversation_id) #{table_name}.*")
        .order(Arel.sql(order))
        .index_by(&:conversation_id)
    end
  end

  def timing_payload(conversation, threshold_minutes, wait_started_at, minutes_waiting)
    {
      waiting_since: conversation.waiting_since&.iso8601,
      wait_started_at: wait_started_at.iso8601,
      minutes_waiting: minutes_waiting,
      threshold_minutes: threshold_minutes,
      severity: severity_for(minutes_waiting, threshold_minutes),
      first_reply_created_at: conversation.first_reply_created_at&.iso8601,
      last_activity_at: conversation.last_activity_at&.iso8601
    }
  end

  def severity_for(minutes_waiting, threshold_minutes)
    return 'critical' if minutes_waiting >= threshold_minutes * 2

    'warning'
  end

  def resource_payload(resource)
    return if resource.blank?

    {
      id: resource.id,
      name: resource.name
    }
  end

  def user_payload(user)
    return if user.blank?

    {
      id: user.id,
      name: user.name,
      email: user.email
    }
  end

  def contact_payload(contact)
    return if contact.blank?

    {
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone_number: contact.phone_number
    }
  end

  def policy_payload(policy)
    {
      id: policy[:id],
      source: policy[:source],
      policy_type: policy[:policy_type]
    }
  end

  def event_payload(event)
    return if event.blank?

    {
      id: event.id,
      event_type: event.event_type,
      reason: event.reason,
      previous_assignee_id: event.previous_assignee_id,
      new_assignee_id: event.new_assignee_id,
      created_at: event.created_at.iso8601
    }
  end

  def summary(alerts)
    {
      scanned: conversations.size,
      alerts: alerts.size,
      by_reason: alerts.group_by { |alert| alert[:reason] }.transform_values(&:size),
      by_severity: alerts.group_by { |alert| alert[:severity] }.transform_values(&:size)
    }
  end

  def filters
    {
      inbox_id: inbox_id,
      team_id: team_id
    }.compact
  end

  def safe_limit
    requested_limit = limit.to_i
    requested_limit = DEFAULT_LIMIT unless requested_limit.positive?

    [requested_limit, MAX_LIMIT].min
  end
end

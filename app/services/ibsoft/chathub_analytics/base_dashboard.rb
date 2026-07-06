class Ibsoft::ChathubAnalytics::BaseDashboard
  EVENT_REDISTRIBUTION_COMPLETED = 'redistribution_completed'.freeze
  EVENT_FIRST_RESPONSE = 'first_response'.freeze
  EVENT_REPLY_TIME = 'reply_time'.freeze
  EVENT_RESOLVED = 'conversation_resolved'.freeze
  EVENT_BOT_HANDOFF = 'conversation_bot_handoff'.freeze

  def initialize(account:, filters: {})
    @account = account
    @filters = filters.to_h.deep_stringify_keys
    @date_range = Ibsoft::ChathubAnalytics::DateRange.new(@filters)
  end

  private

  attr_reader :account, :filters, :date_range

  def normalized_filters
    {
      period: date_range.period,
      inbox_id: inbox_id,
      team_id: team_id
    }.compact
  end

  def reporting_events(name)
    scope = account.reporting_events
                   .where(name: name, event_end_time: date_range.range)
    scope = scope.where(inbox_id: inbox_id) if inbox_id.present?
    scope = scope.joins(:conversation).where(conversations: { team_id: team_id }) if team_id.present?

    scope
  end

  def redistribution_events
    scope = Ibsoft::ConversationDistribution::EventLog
            .where(account: account, event_type: EVENT_REDISTRIBUTION_COMPLETED, created_at: date_range.range)
    scope = scope.where(inbox_id: inbox_id) if inbox_id.present?
    scope = scope.where(team_id: team_id) if team_id.present?

    scope
  end

  def conversations_scope
    scope = account.conversations
    scope = scope.where(inbox_id: inbox_id) if inbox_id.present?
    scope = scope.where(team_id: team_id) if team_id.present?

    scope
  end

  def period_conversations_scope
    conversations_scope.where(created_at: date_range.range)
  end

  def average_seconds(scope)
    scope.average(:value).to_f.round
  end

  def safe_id(key)
    value = filters[key].presence
    return if value.blank?

    parsed_value = value.to_i
    parsed_value.positive? ? parsed_value : nil
  end

  def inbox_id
    @inbox_id ||= safe_id('inbox_id')
  end

  def team_id
    @team_id ||= safe_id('team_id')
  end

  def day_key_expression
    Arel.sql('DATE(event_end_time)')
  end

  def conversation_day_key_expression
    Arel.sql('DATE(created_at)')
  end

  def day_series
    (date_range.starts_at.to_date..date_range.ends_at.to_date).to_a
  end

  def seconds_to_minutes(seconds)
    (seconds.to_f / 60).round(1)
  end
end

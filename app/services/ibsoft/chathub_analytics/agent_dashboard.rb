class Ibsoft::ChathubAnalytics::AgentDashboard < Ibsoft::ChathubAnalytics::BaseDashboard
  RISK_WAIT_MINUTES = 15

  def initialize(account:, user:, filters: {})
    super(account: account, filters: filters)
    @user = user
  end

  def perform
    {
      generated_at: Time.current.iso8601,
      period: date_range.payload,
      filters: normalized_filters,
      summary: summary_payload,
      by_team: by_team_payload,
      daily_response: daily_response_payload,
      suggestions: suggestions_payload
    }
  end

  private

  attr_reader :user

  def agent_reply_events
    @agent_reply_events ||= reporting_events(EVENT_REPLY_TIME).where(user_id: user.id)
  end

  def agent_first_response_events
    @agent_first_response_events ||= reporting_events(EVENT_FIRST_RESPONSE).where(user_id: user.id)
  end

  def agent_resolved_events
    @agent_resolved_events ||= reporting_events(EVENT_RESOLVED).where(user_id: user.id)
  end

  def agent_redistribution_events
    @agent_redistribution_events ||= redistribution_events.where(previous_assignee_id: user.id)
  end

  def open_assigned_conversations
    @open_assigned_conversations ||= conversations_scope.open.where(assignee_id: user.id)
  end

  def risk_conversations
    @risk_conversations ||= open_assigned_conversations
                            .where.not(waiting_since: nil)
                            .where(waiting_since: ..RISK_WAIT_MINUTES.minutes.ago)
  end

  def summary_payload
    {
      open_assigned: open_assigned_conversations.count,
      waiting_customers: open_assigned_conversations.where.not(waiting_since: nil).count,
      at_risk: risk_conversations.count,
      average_reply_seconds: average_seconds(agent_reply_events),
      average_first_response_seconds: average_seconds(agent_first_response_events),
      resolved_count: agent_resolved_events.count,
      redistributions_away_count: agent_redistribution_events.count,
      redistribution_basis_count: assigned_or_answered_total
    }
  end

  def assigned_or_answered_total
    @assigned_or_answered_total ||= agent_resolved_events.select(:conversation_id).distinct.count +
                                    open_assigned_conversations.count
  end

  def by_team_payload
    team_ids = team_ids_for_agent_metrics

    team_ids.map do |current_team_id|
      team = team_index[current_team_id]
      {
        team_id: current_team_id,
        team_name: team&.name || I18n.t('ibsoft.chathub_analytics.not_informed'),
        open_assigned: open_by_team[current_team_id].to_i,
        resolved_count: resolved_by_team[current_team_id].to_i,
        average_reply_seconds: reply_average_by_team[current_team_id].to_i,
        redistributions_away_count: redistributions_by_team[current_team_id].to_i
      }
    end
  end

  def daily_response_payload
    averages = agent_reply_events.group(day_key_expression).average(:value)
    redistributions = agent_redistribution_events.group(Arel.sql('DATE(created_at)')).count
    resolved = agent_resolved_events.group(day_key_expression).count

    day_series.map do |date|
      {
        date: date.iso8601,
        average_reply_seconds: averages[date]&.to_f&.round || 0,
        redistributions_away_count: redistributions[date].to_i,
        resolved_count: resolved[date].to_i
      }
    end
  end

  def suggestions_payload
    summary = summary_payload
    [].tap do |items|
      if summary[:average_reply_seconds] > 30.minutes
        items << suggestion(
          'reduce_response_time',
          average_reply_minutes: seconds_to_minutes(summary[:average_reply_seconds])
        )
      end
      if summary[:redistributions_away_count].positive?
        items << suggestion(
          'review_redistributions',
          count: summary[:redistributions_away_count]
        )
      end
      items << suggestion('prioritize_waiting_customers', count: summary[:at_risk]) if summary[:at_risk].positive?
      items << suggestion('healthy_operation') if items.blank?
    end
  end

  def suggestion(code, payload = {})
    { code: code, payload: payload }
  end

  def team_ids_for_agent_metrics
    [
      open_by_team.keys,
      resolved_by_team.keys,
      reply_average_by_team.keys,
      redistributions_by_team.keys
    ].flatten.compact.uniq.sort
  end

  def team_index
    @team_index ||= account.teams.where(id: team_ids_for_agent_metrics).index_by(&:id)
  end

  def open_by_team
    @open_by_team ||= open_assigned_conversations.group(:team_id).count
  end

  def resolved_by_team
    @resolved_by_team ||= events_grouped_by_team(agent_resolved_events, :count)
  end

  def reply_average_by_team
    @reply_average_by_team ||= events_grouped_by_team(agent_reply_events, :average)
  end

  def redistributions_by_team
    @redistributions_by_team ||= agent_redistribution_events.group(:team_id).count
  end

  def events_grouped_by_team(scope, operation)
    grouped_scope = scope.joins(:conversation).group('conversations.team_id')
    result = operation == :average ? grouped_scope.average(:value) : grouped_scope.count

    result.transform_values { |value| value.to_f.round }
  end
end

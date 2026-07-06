# rubocop:disable Metrics/ClassLength
class Ibsoft::ChathubAnalytics::SupervisorDashboard < Ibsoft::ChathubAnalytics::BaseDashboard
  RANKING_LIMIT = 8
  SLOW_RESPONSE_RANKING_LIMIT = 10

  def perform
    {
      generated_at: Time.current.iso8601,
      period: date_range.payload,
      filters: normalized_filters,
      summary: summary_payload,
      top_agents: top_agents_payload,
      redistribution_ranking: redistribution_ranking_payload,
      slow_response_ranking: slow_response_ranking_payload,
      by_team: by_team_payload,
      daily_volume: daily_volume_payload,
      hourly_heatmap: hourly_heatmap_payload,
      suggestions: suggestions_payload
    }
  end

  private

  def summary_payload
    {
      open_conversations: open_conversations.count,
      unassigned_conversations: unassigned_conversations.count,
      average_first_response_seconds: average_seconds(first_response_events),
      average_resolution_seconds: average_seconds(resolved_events),
      redistributions_count: redistribution_events.count,
      bot_handoffs_count: bot_handoff_events.count,
      redistribution_basis_count: resolved_events.count
    }
  end

  def top_agents_payload
    agent_ids = (resolved_count_by_agent.keys + open_count_by_agent.keys).compact.uniq

    items = agent_ids.map { |agent_id| handled_agent_payload(agent_id) }
    items.sort_by { |item| [-item[:total_handled], item[:agent_name].to_s] }.first(RANKING_LIMIT)
  end

  def redistribution_ranking_payload
    items = redistribution_count_by_agent.map do |agent_id, count|
      redistribution_agent_payload(agent_id, count)
    end
    items.sort_by { |item| [-item[:redistributions_count], item[:agent_name].to_s] }.first(RANKING_LIMIT)
  end

  def slow_response_ranking_payload
    items = first_response_average_by_agent.map do |agent_id, average|
      slow_response_agent_payload(agent_id, average)
    end
    items.sort_by { |item| [-item[:average_first_response_seconds], item[:agent_name].to_s] }.first(SLOW_RESPONSE_RANKING_LIMIT)
  end

  def by_team_payload
    team_ids = [
      open_count_by_team.keys,
      unassigned_count_by_team.keys,
      redistribution_count_by_team.keys,
      first_response_average_by_team.keys
    ].flatten.compact.uniq.sort

    team_ids.map { |current_team_id| team_payload(current_team_id) }
  end

  def daily_volume_payload
    created = period_conversations_scope.group(conversation_day_key_expression).count
    resolved = resolved_events.group(day_key_expression).count
    redistributed = redistribution_events.group(Arel.sql('DATE(created_at)')).count

    day_series.map do |date|
      {
        date: date.iso8601,
        created_count: created[date].to_i,
        resolved_count: resolved[date].to_i,
        redistributions_count: redistributed[date].to_i
      }
    end
  end

  def hourly_heatmap_payload
    grouped = period_conversations_scope
              .group(Arel.sql('EXTRACT(HOUR FROM created_at)::int'))
              .count
              .transform_keys(&:to_i)

    (0..23).map do |hour|
      {
        hour: hour,
        conversations_count: grouped[hour].to_i
      }
    end
  end

  def suggestions_payload
    summary = summary_payload
    [].tap do |items|
      items << suggestion('unassigned_backlog', count: summary[:unassigned_conversations]) if summary[:unassigned_conversations].positive?
      items << suggestion('redistribution_pressure', count: summary[:redistributions_count]) if summary[:redistributions_count].positive?
      if summary[:average_first_response_seconds] > 30.minutes
        items << suggestion(
          'slow_first_response',
          minutes: seconds_to_minutes(summary[:average_first_response_seconds])
        )
      end
      items << suggestion('healthy_operation') if items.blank?
    end
  end

  def suggestion(code, payload = {})
    { code: code, payload: payload }
  end

  def handled_agent_payload(agent_id)
    {
      agent_id: agent_id,
      agent_name: agent_name(agent_id),
      open_count: open_count_by_agent[agent_id].to_i,
      resolved_count: resolved_count_by_agent[agent_id].to_i,
      total_handled: open_count_by_agent[agent_id].to_i + resolved_count_by_agent[agent_id].to_i,
      average_resolution_seconds: resolved_average_by_agent[agent_id].to_i
    }
  end

  def redistribution_agent_payload(agent_id, count)
    {
      agent_id: agent_id,
      agent_name: agent_name(agent_id),
      redistributions_count: count.to_i
    }
  end

  def slow_response_agent_payload(agent_id, average)
    {
      agent_id: agent_id,
      agent_name: agent_name(agent_id),
      average_first_response_seconds: average.to_i,
      first_responses_count: first_response_count_by_agent[agent_id].to_i
    }
  end

  def team_payload(current_team_id)
    {
      team_id: current_team_id,
      team_name: team_name(current_team_id),
      open_count: open_count_by_team[current_team_id].to_i,
      unassigned_count: unassigned_count_by_team[current_team_id].to_i,
      redistributions_count: redistribution_count_by_team[current_team_id].to_i,
      average_first_response_seconds: first_response_average_by_team[current_team_id].to_i
    }
  end

  def agent_name(agent_id)
    agent_index[agent_id]&.name || I18n.t('ibsoft.chathub_analytics.not_informed')
  end

  def team_name(current_team_id)
    team_index[current_team_id]&.name || I18n.t('ibsoft.chathub_analytics.not_informed')
  end

  def open_conversations
    @open_conversations ||= conversations_scope.open
  end

  def unassigned_conversations
    @unassigned_conversations ||= open_conversations.unassigned
  end

  def first_response_events
    @first_response_events ||= reporting_events(EVENT_FIRST_RESPONSE)
  end

  def resolved_events
    @resolved_events ||= reporting_events(EVENT_RESOLVED)
  end

  def bot_handoff_events
    @bot_handoff_events ||= reporting_events(EVENT_BOT_HANDOFF)
  end

  def open_count_by_agent
    @open_count_by_agent ||= open_conversations.where.not(assignee_id: nil).group(:assignee_id).count
  end

  def resolved_count_by_agent
    @resolved_count_by_agent ||= resolved_events.where.not(user_id: nil).group(:user_id).count
  end

  def resolved_average_by_agent
    @resolved_average_by_agent ||= resolved_events
                                   .where.not(user_id: nil)
                                   .group(:user_id)
                                   .average(:value)
                                   .transform_values { |value| value.to_f.round }
  end

  def redistribution_count_by_agent
    @redistribution_count_by_agent ||= redistribution_events.where.not(previous_assignee_id: nil).group(:previous_assignee_id).count
  end

  def first_response_average_by_agent
    @first_response_average_by_agent ||= first_response_events
                                         .where.not(user_id: nil)
                                         .group(:user_id)
                                         .average(:value)
                                         .transform_values { |value| value.to_f.round }
  end

  def first_response_count_by_agent
    @first_response_count_by_agent ||= first_response_events.where.not(user_id: nil).group(:user_id).count
  end

  def agent_index
    @agent_index ||= account.users.where(id: agent_ids_for_rankings).index_by(&:id)
  end

  def agent_ids_for_rankings
    [
      open_count_by_agent.keys,
      resolved_count_by_agent.keys,
      redistribution_count_by_agent.keys,
      first_response_average_by_agent.keys
    ].flatten.compact.uniq
  end

  def open_count_by_team
    @open_count_by_team ||= open_conversations.group(:team_id).count
  end

  def unassigned_count_by_team
    @unassigned_count_by_team ||= unassigned_conversations.group(:team_id).count
  end

  def redistribution_count_by_team
    @redistribution_count_by_team ||= redistribution_events.group(:team_id).count
  end

  def first_response_average_by_team
    @first_response_average_by_team ||= first_response_events
                                        .joins(:conversation)
                                        .group('conversations.team_id')
                                        .average(:value)
                                        .transform_values { |value| value.to_f.round }
  end

  def team_index
    @team_index ||= account.teams.where(id: team_ids_for_index).index_by(&:id)
  end

  def team_ids_for_index
    [
      open_count_by_team.keys,
      unassigned_count_by_team.keys,
      redistribution_count_by_team.keys,
      first_response_average_by_team.keys
    ].flatten.compact.uniq
  end
end
# rubocop:enable Metrics/ClassLength

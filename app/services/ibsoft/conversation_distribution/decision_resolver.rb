class Ibsoft::ConversationDistribution::DecisionResolver
  ACTION_ASSIGN = 'assign'.freeze
  ACTION_SKIP = 'skip'.freeze
  ACTION_WAIT = 'wait'.freeze
  ACTION_NOTIFY_CUSTOMER = 'notify_customer'.freeze
  ACTION_FALLBACK_TEAM = 'fallback_team'.freeze

  def initialize(conversation:, candidate:, now: Time.current)
    @conversation = conversation
    @candidate = candidate
    @now = now
  end

  def perform
    return decision(ACTION_SKIP, 'not_eligible', candidate_reasons: candidate_reasons) unless candidate_eligible?
    return unavailable_decision('outside_business_hours') unless within_business_hours?

    decision(ACTION_ASSIGN, 'eligible_for_assignment')
  end

  def unavailable_decision(reason = 'no_available_agent')
    unavailable_config = unavailable_config_for(reason)
    action = unavailable_action(unavailable_config)

    case action
    when 'notify_customer'
      decision(
        ACTION_NOTIFY_CUSTOMER,
        reason,
        unavailable_payload(unavailable_config).merge(message_present: unavailable_message(unavailable_config).present?)
      )
    when 'fallback_team'
      fallback_team_id = fallback_team_id(unavailable_config)
      fallback_team_id.present? ? fallback_team_decision(reason, unavailable_config) : wait_decision(reason, unavailable_config)
    else
      wait_decision(reason, unavailable_config)
    end
  end

  private

  attr_reader :conversation, :candidate, :now

  def candidate_eligible?
    candidate[:eligible] || candidate['eligible']
  end

  def candidate_reasons
    candidate[:reasons] || candidate['reasons'] || []
  end

  def decision(action, reason, metadata = {})
    {
      action: action,
      reason: reason,
      policy_id: policy[:id],
      policy_source: policy[:source],
      policy_type: policy[:policy_type],
      business_hours_mode: business_hours_mode
    }.merge(within_business_hours_payload).merge(metadata)
  end

  def within_business_hours_payload
    return {} unless defined?(@within_business_hours)

    { within_business_hours: @within_business_hours }
  end

  def unavailable_payload(unavailable_config)
    {
      unavailable_action: unavailable_action(unavailable_config),
      fallback_team_id: fallback_team_id(unavailable_config)
    }
  end

  def fallback_team_decision(reason, unavailable_config)
    decision(ACTION_FALLBACK_TEAM, reason, unavailable_payload(unavailable_config).merge(fallback_team_configured: true))
  end

  def wait_decision(reason, unavailable_config)
    decision(ACTION_WAIT, reason, unavailable_payload(unavailable_config))
  end

  def within_business_hours?
    @within_business_hours = case business_hours_mode
                             when 'always_available'
                               true
                             when 'custom'
                               custom_schedule_open?
                             else
                               inbox_working_now?
                             end
  end

  def inbox_working_now?
    return true unless conversation.inbox.working_hours_enabled?

    conversation.inbox.working_now?
  end

  def custom_schedule_open?
    return true if custom_schedule.blank?

    working_day = custom_schedule_day
    return true if working_day.blank?
    return false if working_day_closed?(working_day)
    return !inside_custom_break? if working_day_open_all_day?(working_day)
    return true unless working_day_values_present?(working_day)

    inside_working_day_window?(working_day) && !inside_custom_break?
  end

  def custom_schedule_day
    custom_schedule.find { |item| item['day_of_week'].to_i == local_now.wday }
  end

  def working_day_closed?(working_day)
    ActiveModel::Type::Boolean.new.cast(working_day['closed_all_day'])
  end

  def working_day_open_all_day?(working_day)
    ActiveModel::Type::Boolean.new.cast(working_day['open_all_day'])
  end

  def inside_working_day_window?(working_day)
    local_now.between?(day_time(working_day['open_hour'], working_day['open_minutes']),
                       day_time(working_day['close_hour'], working_day['close_minutes']))
  end

  def working_day_values_present?(working_day)
    %w[open_hour open_minutes close_hour close_minutes].all? { |key| working_day[key].present? }
  end

  def day_time(hour, minutes)
    local_now.change(hour: hour.to_i, min: minutes.to_i)
  end

  def local_now
    @local_now ||= now.in_time_zone(custom_timezone)
  end

  def custom_timezone
    ActiveSupport::TimeZone[business_hours_config['timezone']].presence || conversation.inbox.timezone
  end

  def custom_schedule
    Array(business_hours_config['schedule']).map(&:stringify_keys)
  end

  def inside_custom_break?
    custom_breaks
      .select { |item| item['day_of_week'].to_i == local_now.wday }
      .any? { |item| custom_break_contains?(item) }
  end

  def custom_break_contains?(break_config)
    current_minutes = (local_now.hour * 60) + local_now.min
    current_minutes >= break_start_minutes(break_config) && current_minutes < break_end_minutes(break_config)
  end

  def break_start_minutes(break_config)
    (break_config['start_hour'].to_i * 60) + break_config['start_minutes'].to_i
  end

  def break_end_minutes(break_config)
    (break_config['end_hour'].to_i * 60) + break_config['end_minutes'].to_i
  end

  def custom_breaks
    Array(business_hours_config['breaks']).map(&:stringify_keys)
  end

  def business_hours_mode
    business_hours_config['mode']
  end

  def business_hours_config
    policy_config['business_hours'] || {}
  end

  def unavailable_action(unavailable_config)
    unavailable_config['action'].presence || 'wait'
  end

  def fallback_team_id(unavailable_config)
    unavailable_config['fallback_team_id'].presence
  end

  def unavailable_message(unavailable_config)
    unavailable_config['message']
  end

  def unavailable_config_for(reason)
    Ibsoft::ConversationDistribution::UnavailabilityConfig.for(policy_config, reason)
  end

  def policy_config
    policy[:config] || policy['config'] || {}
  end

  def policy
    @policy ||= Ibsoft::ConversationDistribution::EffectivePolicyResolver.new(
      account: conversation.account,
      inbox: conversation.inbox,
      team: conversation.team
    ).perform
  end
end

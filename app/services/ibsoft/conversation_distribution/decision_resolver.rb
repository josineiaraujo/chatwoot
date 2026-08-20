class Ibsoft::ConversationDistribution::DecisionResolver
  ACTION_ASSIGN = 'assign'.freeze
  ACTION_SKIP = 'skip'.freeze
  ACTION_WAIT = 'wait'.freeze
  ACTION_NOTIFY_CUSTOMER = 'notify_customer'.freeze
  ACTION_FALLBACK_TEAM = 'fallback_team'.freeze
  ACTION_AFTER_HOURS_POLICY = 'after_hours_policy'.freeze

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
    when 'after_hours_policy'
      after_hours_policy_decision(reason, unavailable_config)
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

    { within_business_hours: @within_business_hours }.merge(outside_business_hours_payload)
  end

  def unavailable_payload(unavailable_config)
    {
      unavailable_action: unavailable_action(unavailable_config),
      fallback_team_id: fallback_team_id(unavailable_config),
      after_hours_policy_id: policy[:after_hours_policy_id]
    }
  end

  def fallback_team_decision(reason, unavailable_config)
    decision(ACTION_FALLBACK_TEAM, reason, unavailable_payload(unavailable_config).merge(fallback_team_configured: true))
  end

  def wait_decision(reason, unavailable_config)
    decision(ACTION_WAIT, reason, unavailable_payload(unavailable_config))
  end

  def after_hours_policy_decision(reason, unavailable_config)
    return wait_decision(reason, unavailable_config) unless enabled_after_hours_policy?

    decision(
      ACTION_AFTER_HOURS_POLICY,
      reason,
      unavailable_payload(unavailable_config).merge(after_hours_policy_name: policy[:after_hours_policy_name])
    )
  end

  def within_business_hours?
    if holiday_for_today.present?
      @outside_business_hours_cause = 'holiday'
      @within_business_hours = false
      return false
    end

    @within_business_hours = business_hours_evaluator.open?
    @outside_business_hours_cause = 'schedule' unless @within_business_hours
    @within_business_hours
  end

  def outside_business_hours_payload
    return {} unless @within_business_hours == false

    payload = { outside_business_hours_cause: @outside_business_hours_cause }
    return payload if holiday_for_today.blank?

    payload.merge(
      business_calendar_id: holiday_for_today[:business_calendar_id],
      business_holiday_id: holiday_for_today[:id],
      holiday_name: holiday_for_today[:name],
      holiday_date: holiday_for_today[:holiday_date]
    )
  end

  def holiday_for_today
    return @holiday_for_today if defined?(@holiday_for_today)
    return if conversation.team.blank?

    @holiday_for_today = Ibsoft::BusinessCalendar::HolidayResolver.new(
      account: conversation.account,
      team: conversation.team,
      date: local_now.to_date
    ).perform
  end

  def enabled_after_hours_policy?
    after_hours_policy_id = policy[:after_hours_policy_id]
    return false if after_hours_policy_id.blank?

    Ibsoft::AfterHours::Policy.exists?(
      id: after_hours_policy_id,
      account_id: conversation.account_id,
      enabled: true
    )
  end

  def local_now
    business_hours_evaluator.local_now
  end

  def business_hours_evaluator
    @business_hours_evaluator ||= Ibsoft::ConversationDistribution::BusinessHoursEvaluator.new(
      conversation: conversation,
      config: business_hours_config,
      now: now
    )
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

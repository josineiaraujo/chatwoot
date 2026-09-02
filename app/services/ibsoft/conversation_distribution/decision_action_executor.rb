require 'digest'

class Ibsoft::ConversationDistribution::DecisionActionExecutor
  ACTION_RECORDS_KEY = 'ibsoft_distribution_action_records'.freeze
  FALLBACK_HISTORY_KEY = 'ibsoft_distribution_fallback_team_ids'.freeze

  ACTIONS_WITH_EFFECTS = [
    Ibsoft::ConversationDistribution::DecisionResolver::ACTION_NOTIFY_CUSTOMER,
    Ibsoft::ConversationDistribution::DecisionResolver::ACTION_FALLBACK_TEAM,
    Ibsoft::ConversationDistribution::DecisionResolver::ACTION_AFTER_HOURS_POLICY
  ].freeze

  def initialize(conversation:, decision:, candidate: {})
    @conversation = conversation
    @decision = decision.deep_dup
    @candidate = candidate
  end

  def perform
    return decision unless actionable?

    return perform_after_hours_policy_action if decision[:action] == Ibsoft::ConversationDistribution::DecisionResolver::ACTION_AFTER_HOURS_POLICY
    return perform_notify_customer_action if decision[:action] == Ibsoft::ConversationDistribution::DecisionResolver::ACTION_NOTIFY_CUSTOMER

    perform_locked_action
  end

  private

  attr_reader :conversation, :decision, :candidate

  def perform_locked_action
    result = nil
    with_reloaded_lock do
      result = if action_already_applied?
                 already_applied_decision
               else
                 action_result = apply_action
                 persist_action_record(action_result)
                 decision.merge(action_applied: action_result[:applied], action_result: action_result)
               end
    end
    result
  end

  def perform_notify_customer_action
    return already_applied_decision unless reserve_action_record

    action_result = notify_customer
    persist_action_record_with_lock(action_result)
    decision.merge(action_applied: action_result[:applied], action_result: action_result)
  rescue StandardError
    remove_action_record_with_lock
    raise
  end

  def perform_after_hours_policy_action
    action_result = Ibsoft::AfterHours::WaitStarter.new(conversation: conversation, decision: decision).perform
    decision.merge(action_applied: action_result[:applied], action_result: action_result)
  end

  def actionable? = ACTIONS_WITH_EFFECTS.include?(decision[:action])

  def apply_action
    case decision[:action]
    when Ibsoft::ConversationDistribution::DecisionResolver::ACTION_NOTIFY_CUSTOMER
      notify_customer
    when Ibsoft::ConversationDistribution::DecisionResolver::ACTION_FALLBACK_TEAM
      apply_fallback_team
    end
  end

  def notify_customer
    return action_result(false, 'blank_message') if unavailable_message.blank?

    message = Messages::MessageBuilder.new(nil, conversation, notify_message_params).perform

    action_result(true, 'message_sent', message_id: message.id)
  end

  def notify_message_params
    {
      content: unavailable_message,
      private: false,
      content_attributes: {
        ibsoft_conversation_distribution: {
          action: decision[:action],
          reason: decision[:reason]
        }
      }
    }
  end

  def apply_fallback_team
    fallback_team = conversation.account.teams.find_by(id: decision[:fallback_team_id])
    return action_result(false, 'fallback_team_not_found') if fallback_team.blank?
    return action_result(false, 'fallback_team_same_as_current') if fallback_team.id == conversation.team_id
    return action_result(false, 'fallback_cycle_detected') if fallback_history.include?(fallback_team.id)

    previous_team_id = conversation.team_id
    attributes = marked_attributes_for_fallback(previous_team_id, fallback_team.id)
    assign_fallback_team(fallback_team, attributes)

    action_result(true, 'fallback_team_assigned', previous_team_id: previous_team_id, new_team_id: fallback_team.id)
  end

  def assign_fallback_team(fallback_team, attributes)
    Ibsoft::ConversationOwnership::Clearer.perform(conversation)
    conversation.update!(team: fallback_team, additional_attributes: attributes)
  end

  def marked_attributes_for_fallback(previous_team_id, fallback_team_id)
    attributes = additional_attributes
    attributes[Ibsoft::ConversationDistribution::SourceResolver::ATTRIBUTE_KEY] = 'system_team_transfer'
    attributes[Ibsoft::ConversationDistribution::SourceMarker::MARKED_AT_KEY] = Time.current.iso8601
    attributes[Ibsoft::ConversationDistribution::SourceMarker::REASON_KEY] = 'fallback_team'
    attributes[FALLBACK_HISTORY_KEY] = (fallback_history + [previous_team_id, fallback_team_id]).compact.uniq
    attributes
  end

  def unavailable_message
    @unavailable_message ||= Ibsoft::ConversationDistribution::UnavailabilityConfig
                             .for(policy_config, decision[:reason])['message'].to_s
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

  def already_applied_decision
    decision.merge(
      action_applied: false,
      action_result: action_result(false, 'already_applied')
    )
  end

  def action_already_applied?
    action_records.key?(action_key)
  end

  def reserve_action_record
    reserved = false
    with_reloaded_lock do
      next if action_already_applied?

      persist_action_record(action_result(false, 'processing'))
      reserved = true
    end
    reserved
  end

  def persist_action_record_with_lock(action_result)
    with_reloaded_lock do
      persist_action_record(action_result)
    end
  end

  def remove_action_record_with_lock
    with_reloaded_lock do
      attributes = additional_attributes
      records = action_records
      records.delete(action_key)
      conversation.update!(additional_attributes: attributes.merge(ACTION_RECORDS_KEY => records))
    end
  end

  def persist_action_record(action_result)
    attributes = additional_attributes
    records = action_records
    records[action_key] = {
      action: decision[:action],
      reason: decision[:reason],
      result: action_result[:status],
      applied: action_result[:applied],
      recorded_at: Time.current.iso8601
    }
    attributes[ACTION_RECORDS_KEY] = records
    conversation.update!(additional_attributes: attributes)
  end

  def action_records
    additional_attributes.fetch(ACTION_RECORDS_KEY, {}).to_h
  end

  def fallback_history = Array(additional_attributes[FALLBACK_HISTORY_KEY]).map(&:to_i)

  def additional_attributes
    @additional_attributes = (conversation.additional_attributes || {}).deep_dup
  end

  def action_key
    @action_key ||= [
      decision[:action],
      decision[:reason],
      decision[:policy_id],
      decision[:fallback_team_id],
      Digest::SHA256.hexdigest(unavailable_message)
    ].join(':')
  end

  def action_result(applied, status, metadata = {}) = { applied: applied, status: status }.merge(metadata)

  def with_reloaded_lock(&)
    conversation.reload
    conversation.with_lock(&)
  end
end

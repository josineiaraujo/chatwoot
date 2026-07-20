class Ibsoft::ConversationDistribution::QueueReturnService
  EVENT_TYPE = 'queue_returned'.freeze
  SOURCE = 'manual_team_transfer'.freeze

  class Error < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super(code)
    end
  end

  def initialize(conversation:, actor:, team:, strict: true)
    @conversation = conversation
    @actor = actor
    @team = team
    @strict = strict
  end

  def perform
    result = nil

    conversation.reload
    conversation.with_lock do
      error_code = validation_error
      raise Error, error_code if error_code.present?

      result = return_to_queue
    end

    return result unless result[:queued]

    result.merge(post_return_actions(result))
  rescue Error => e
    raise if strict

    unavailable_result(e.code)
  end

  private

  attr_reader :conversation, :actor, :team, :strict

  def validation_error
    conversation_validation_error || execution_validation_error || policy_validation_error
  end

  def conversation_validation_error
    return 'queue_return_not_open' unless conversation.open?
    return 'queue_return_actor_not_assignee' unless conversation.assignee == actor
    return 'queue_return_missing_team' if team.blank? || team.account_id != conversation.account_id
  end

  def execution_validation_error
    return 'queue_return_distribution_disabled' unless Ibsoft::ConversationDistribution::ExecutionConfig.job_enabled?
    return 'queue_return_real_assignment_disabled' unless real_assignment_enabled?
    return 'queue_return_native_assignment_enabled' if team.allow_auto_assign?
  end

  def policy_validation_error
    return 'queue_return_policy_disabled' unless effective_policy[:enabled]
    return 'queue_return_source_not_allowed' unless eligible_sources.include?(SOURCE)
  end

  def return_to_queue
    previous_assignee = conversation.assignee
    previous_team = conversation.team
    queue_entered_at = Time.current

    mark_source
    conversation.assign_attributes(
      team: team,
      assignee: nil,
      assignee_agent_bot: nil,
      waiting_since: queue_entered_at
    )
    conversation.save!

    result_payload(
      previous_assignee,
      previous_team,
      queue_entered_at,
      log_event(previous_assignee, previous_team, queue_entered_at)
    )
  end

  def result_payload(previous_assignee, previous_team, queue_entered_at, event)
    {
      queued: true,
      conversation_id: conversation.id,
      display_id: conversation.display_id,
      previous_assignee: previous_assignee,
      previous_team: previous_team,
      team: team,
      queue_entered_at: queue_entered_at,
      event_id: event.id
    }
  end

  def real_assignment_enabled?
    Ibsoft::ConversationDistribution::ExecutionConfig.real_assignment_enabled?
  end

  def mark_source
    Ibsoft::ConversationDistribution::SourceMarker.new(
      conversation: conversation,
      source: SOURCE,
      reason: Ibsoft::ConversationDistribution::QueueReturnMarker::REASON
    ).assign
  end

  def log_event(previous_assignee, previous_team, queue_entered_at)
    event_logger.log(
      conversation: conversation,
      event_type: EVENT_TYPE,
      reason: Ibsoft::ConversationDistribution::QueueReturnMarker::REASON,
      payload: {
        assignment: {
          previous_assignee: previous_assignee,
          new_assignee: nil
        },
        metadata: {
          returned_by_user_id: actor.id,
          previous_team_id: previous_team&.id,
          target_team_id: team.id,
          queue_entered_at: queue_entered_at.iso8601
        }
      }
    )
  end

  def post_return_actions(result)
    previous_assignee = result[:previous_assignee]

    {
      attention_notifications: sync_attention_notifications(previous_assignee),
      previous_assignee_participation: cleanup_previous_assignee_participation(previous_assignee),
      activity_message: notify_activity(previous_assignee)
    }
  end

  def sync_attention_notifications(previous_assignee)
    Ibsoft::ConversationDistribution::AttentionNotificationSync.new(
      account: conversation.account,
      conversation: conversation,
      previous_assignee: previous_assignee
    ).perform
  end

  def cleanup_previous_assignee_participation(previous_assignee)
    Ibsoft::ConversationDistribution::PreviousAssigneeParticipationCleanup.new(
      account: conversation.account,
      conversation: conversation,
      previous_assignee: previous_assignee
    ).perform
  end

  def notify_activity(previous_assignee)
    Ibsoft::ConversationDistribution::ActivityMessageNotifier.new(
      conversation: conversation,
      action: :queue_returned,
      assignee: previous_assignee,
      target_team: team
    ).perform
  end

  def effective_policy
    @effective_policy ||= Ibsoft::ConversationDistribution::EffectivePolicyResolver.new(
      account: conversation.account,
      inbox: conversation.inbox,
      team: team
    ).perform
  end

  def eligible_sources
    Array(effective_policy.dig(:config, 'eligible_sources'))
  end

  def event_logger
    @event_logger ||= Ibsoft::ConversationDistribution::EventLogger.new(account: conversation.account)
  end

  def unavailable_result(error_code)
    {
      queued: false,
      reason: error_code
    }
  end
end

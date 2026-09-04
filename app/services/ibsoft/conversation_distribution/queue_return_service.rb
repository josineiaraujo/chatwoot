class Ibsoft::ConversationDistribution::QueueReturnService
  EVENT_TYPE = 'queue_returned'.freeze
  SOURCE = 'manual_team_transfer'.freeze
  MODES = %i[self_return manual_transfer].freeze

  class Error < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super(code)
    end
  end

  def initialize(conversation:, actor:, team:, strict: true, mode: :self_return)
    @conversation = conversation
    @actor = actor
    @team = team
    @strict = strict
    @mode = mode.to_sym
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

  attr_reader :conversation, :actor, :team, :strict, :mode

  def validation_error
    conversation_validation_error || execution_validation_error || policy_validation_error
  end

  def conversation_validation_error
    return 'queue_return_invalid_mode' unless MODES.include?(mode)
    return 'queue_return_missing_team' if team.blank? || team.account_id != conversation.account_id

    manual_transfer? ? manual_transfer_validation_error : self_return_validation_error
  end

  def manual_transfer_validation_error
    return 'queue_return_resolved' if conversation.resolved?
    return 'queue_return_already_queued' if Ibsoft::ConversationDistribution::QueueReturnMarker.waiting_in?(conversation, team)

    permission = Ibsoft::ConversationDistribution::ManualTransferPermission.new(conversation: conversation, actor: actor)
    return 'queue_return_assigned_forbidden' unless permission.allowed?
  end

  def self_return_validation_error
    return 'queue_return_not_open' unless conversation.open?
    return 'queue_return_actor_not_assignee' unless conversation.assignee == actor
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
    Ibsoft::ConversationOwnership::Clearer.perform(conversation)
    conversation.assign_attributes(
      team: team,
      status: :open,
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
      activity_message: notify_activity(previous_assignee),
      distribution_job: enqueue_distribution
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
      action: manual_transfer? ? :queue_transferred : :queue_returned,
      assignee: manual_transfer? ? actor : previous_assignee,
      target_team: team
    ).perform
  end

  def enqueue_distribution
    Ibsoft::ConversationDistribution::ScopedWatchdogEnqueuer.new(
      conversation: conversation,
      team: team
    ).perform
  end

  def manual_transfer? = mode == :manual_transfer

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

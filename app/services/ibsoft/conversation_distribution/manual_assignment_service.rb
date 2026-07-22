class Ibsoft::ConversationDistribution::ManualAssignmentService
  ASSIGNMENT_TYPES = %w[agent team].freeze

  class Error < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super(code)
    end
  end

  def initialize(conversation:, actor:, assignment_type:, target_id:)
    @conversation = conversation
    @actor = actor
    @assignment_type = assignment_type.to_s
    @raw_target_id = target_id
  end

  def perform
    raise Error, 'manual_assignment_invalid_type' unless ASSIGNMENT_TYPES.include?(assignment_type)

    validate_target_id!

    assignment_type == 'agent' ? assign_agent : assign_team
  end

  private

  attr_reader :conversation, :actor, :assignment_type, :raw_target_id

  def assign_agent
    return remove_agent if target_id.blank? || target_id.zero?

    agent = nil
    previous_assignee = nil
    update_locked_conversation do
      agent = target_agent
      raise Error, 'manual_assignment_agent_not_found' if agent.blank?

      previous_assignee = conversation.assignee
      conversation.assign_attributes(
        status: :open,
        assignee: agent,
        assignee_agent_bot: nil
      )
    end
    cleanup_previous_assignee(previous_assignee, agent)

    result_payload
  end

  def remove_agent
    reject_resolved_conversation!
    queue_result = Ibsoft::ConversationDistribution::QueueReturnService.new(
      conversation: conversation,
      actor: actor,
      team: conversation.team,
      strict: false,
      mode: :manual_transfer
    ).perform
    return result_payload(queue_returned: true) if queue_result[:queued]

    update_locked_conversation do
      conversation.assign_attributes(assignee: nil, assignee_agent_bot: nil)
    end

    result_payload
  end

  def assign_team
    team = target_team
    transfer_preparer = nil
    previous_assignee = nil

    update_locked_conversation do
      previous_assignee = conversation.assignee
      if team.present?
        transfer_preparer = Ibsoft::ConversationDistribution::TeamTransferPreparer.new(
          conversation: conversation,
          team: team
        )
        transfer_preparer.prepare
      end

      conversation.assign_attributes(team: team, status: :open)
      conversation.waiting_since ||= Time.current if team.present?
    end
    cleanup_previous_assignee(previous_assignee, conversation.assignee)

    distribution_enqueued = enqueue_distribution(transfer_preparer, team)
    result_payload(distribution_enqueued: distribution_enqueued)
  end

  def target_team
    return if target_id.blank? || target_id.zero?

    conversation.account.teams.find_by(id: target_id).tap do |team|
      raise Error, 'manual_assignment_team_not_found' if team.blank?
    end
  end

  def target_agent
    account_user = AccountUser.find_by(account_id: conversation.account_id, user_id: target_id)
    return if account_user.blank?
    return account_user.user if account_user.administrator?
    return account_user.user if conversation.inbox.inbox_members.exists?(user_id: target_id)
  end

  def update_locked_conversation
    conversation.reload
    conversation.with_lock do
      reject_resolved_conversation!(reload: false)
      reject_assigned_conversation!
      yield
      conversation.save!
    end
  end

  def reject_resolved_conversation!(reload: true)
    conversation.reload if reload
    raise Error, 'manual_assignment_resolved' if conversation.resolved?
  end

  def reject_assigned_conversation!
    return if manual_transfer_permission.allowed?

    raise Error, 'manual_assignment_assigned_forbidden'
  end

  def manual_transfer_permission
    @manual_transfer_permission ||= Ibsoft::ConversationDistribution::ManualTransferPermission.new(
      conversation: conversation,
      actor: actor
    )
  end

  def enqueue_distribution(transfer_preparer, team)
    return false unless transfer_preparer&.prepared_for_distribution?
    return false unless conversation.open? && conversation.assignee_id.blank? && conversation.assignee_agent_bot_id.blank?

    Ibsoft::ConversationDistribution::ScopedWatchdogEnqueuer.new(
      conversation: conversation,
      team: team
    ).perform[:enqueued]
  end

  def cleanup_previous_assignee(previous_assignee, new_assignee)
    Ibsoft::ConversationDistribution::AttentionNotificationSync.new(
      account: conversation.account,
      conversation: conversation,
      previous_assignee: previous_assignee,
      new_assignee: new_assignee
    ).perform
    Ibsoft::ConversationDistribution::PreviousAssigneeParticipationCleanup.new(
      account: conversation.account,
      conversation: conversation,
      previous_assignee: previous_assignee,
      new_assignee: new_assignee
    ).perform
  end

  def validate_target_id!
    target_id
  end

  def target_id
    return @target_id if defined?(@target_id)
    return @target_id = nil if raw_target_id.blank?

    @target_id = parse_target_id
    raise Error, 'manual_assignment_invalid_target' if @target_id.nil?

    @target_id
  end

  def parse_target_id
    return raw_target_id if raw_target_id.is_a?(Integer) && raw_target_id >= 0
    return raw_target_id.to_i if raw_target_id.is_a?(String) && raw_target_id.match?(/\A\d+\z/)
  end

  def result_payload(distribution_enqueued: false, queue_returned: false)
    {
      conversation: conversation.reload,
      distribution_enqueued: distribution_enqueued,
      queue_returned: queue_returned
    }
  end
end

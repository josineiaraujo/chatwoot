class Ibsoft::ConversationDistribution::TeamTransferPreparer
  def initialize(conversation:, team:)
    @conversation = conversation
    @team = team
  end

  def prepare
    return conversation unless distribution_candidate?

    mark_distribution_source
    @prepared_for_distribution = enqueue_for_ibsoft_distribution?
    return conversation unless prepared_for_distribution?

    clear_assignees
    conversation
  end

  def prepared_for_distribution?
    @prepared_for_distribution == true
  end

  private

  attr_reader :conversation, :team

  def mark_distribution_source
    Ibsoft::ConversationDistribution::SourceMarker.new(
      conversation: conversation,
      source: distribution_source
    ).assign
  end

  def clear_assignees
    Ibsoft::ConversationOwnership::Clearer.perform(conversation)
  end

  def enqueue_for_ibsoft_distribution?
    return false unless distribution_execution_enabled?
    return false if team.allow_auto_assign?

    policy_enabled? && source_allowed?
  end

  def distribution_candidate?
    team.present? && (conversation.team_id != team.id || conversation.assignee_id.blank?)
  end

  def distribution_execution_enabled?
    Ibsoft::ConversationDistribution::ExecutionConfig.job_enabled? &&
      Ibsoft::ConversationDistribution::ExecutionConfig.real_assignment_enabled?
  end

  def policy_enabled?
    effective_policy[:enabled]
  end

  def source_allowed?
    eligible_sources.include?(distribution_source)
  end

  def eligible_sources
    Array(effective_policy.dig(:config, 'eligible_sources'))
  end

  def distribution_source
    return 'system_team_transfer' if Current.executed_by.present?
    return 'system_team_transfer' if Current.user.is_a?(AgentBot)

    'manual_team_transfer'
  end

  def effective_policy
    @effective_policy ||= Ibsoft::ConversationDistribution::EffectivePolicyResolver.new(
      account: conversation.account,
      inbox: conversation.inbox,
      team: team
    ).perform
  end
end

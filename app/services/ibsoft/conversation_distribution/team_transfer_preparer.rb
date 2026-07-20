class Ibsoft::ConversationDistribution::TeamTransferPreparer
  def initialize(conversation:, team:)
    @conversation = conversation
    @team = team
  end

  def prepare
    mark_distribution_source
    clear_assignees if enqueue_for_ibsoft_distribution?
    conversation
  end

  private

  attr_reader :conversation, :team

  def mark_distribution_source
    Ibsoft::ConversationDistribution::SourceMarker.new(conversation: conversation).assign
  end

  def clear_assignees
    conversation.assignee = nil
    conversation.assignee_agent_bot = nil
  end

  def enqueue_for_ibsoft_distribution?
    return false if team.blank? || conversation.team_id == team.id
    return false unless Ibsoft::ConversationDistribution::ExecutionConfig.job_enabled?
    return false unless Ibsoft::ConversationDistribution::ExecutionConfig.real_assignment_enabled?
    return false if team.allow_auto_assign?

    policy_enabled? && source_allowed?
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
    conversation.additional_attributes[Ibsoft::ConversationDistribution::SourceResolver::ATTRIBUTE_KEY]
  end

  def effective_policy
    @effective_policy ||= Ibsoft::ConversationDistribution::EffectivePolicyResolver.new(
      account: conversation.account,
      inbox: conversation.inbox,
      team: team
    ).perform
  end
end

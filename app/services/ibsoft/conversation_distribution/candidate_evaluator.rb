class Ibsoft::ConversationDistribution::CandidateEvaluator
  def initialize(conversation:, policy:, source:)
    @conversation = conversation
    @policy = policy
    @source = source
  end

  def perform
    {
      eligible: reasons.empty?,
      reasons: reasons
    }
  end

  private

  attr_reader :conversation, :policy, :source

  def reasons
    @reasons ||= build_reasons
  end

  def build_reasons
    [].tap do |items|
      items << 'not_open' unless conversation.open?
      items << 'human_assignee_present' if conversation.assignee_id.present?
      items << 'missing_team' if conversation.team_id.blank?
      items << 'first_human_reply_present' if first_human_reply_blocks_assignment?
      items << 'missing_waiting_since' if conversation.waiting_since.blank?
      items << 'policy_disabled' unless policy_enabled?
      items << source_reason
    end.compact
  end

  def policy_enabled?
    policy[:enabled] || policy['enabled']
  end

  def first_human_reply_blocks_assignment?
    conversation.first_reply_created_at.present? &&
      !Ibsoft::ConversationDistribution::QueueReturnMarker.marked?(conversation)
  end

  def source_reason
    return 'missing_source' if source[:source].blank?
    return if eligible_sources.include?(source[:source])

    'source_not_allowed'
  end

  def eligible_sources
    Array(policy_config['eligible_sources'])
  end

  def policy_config
    policy[:config] || policy['config'] || {}
  end
end

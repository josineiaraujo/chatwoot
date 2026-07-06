class Ibsoft::ConversationDistribution::AgentAssignmentRequestGuard
  def initialize(account:, user:, conversation_ids:)
    @account = account
    @user = user
    @conversation_ids = Array(conversation_ids).compact_blank.map(&:to_i).uniq
  end

  def reason_for(conversation_id)
    return 'required_assignments_missing' if required_assignments_missing?
    return 'not_available_for_agent' unless preview_candidate_by_id.key?(conversation_id)
  end

  def candidate_for(conversation_id)
    preview_candidate_by_id[conversation_id]
  end

  private

  attr_reader :account, :user, :conversation_ids

  def required_assignments_missing?
    (required_conversation_ids - conversation_ids).present?
  end

  def required_conversation_ids
    preview_candidates.filter_map { |candidate| candidate[:conversation_id] if candidate[:required] }
  end

  def preview_candidate_by_id
    @preview_candidate_by_id ||= preview_candidates.index_by { |candidate| candidate[:conversation_id] }
  end

  def preview_candidates
    @preview_candidates ||= Ibsoft::ConversationDistribution::AgentAssignmentPreview.new(
      account: account,
      user: user,
      limit: Ibsoft::ConversationDistribution::AgentAssignmentPreview::MAX_LIMIT
    ).perform[:candidates]
  end
end

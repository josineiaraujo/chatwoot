class Ibsoft::ConversationDistribution::AgentAssignmentPreview
  DEFAULT_LIMIT = Ibsoft::ConversationDistribution::CandidateFinder::DEFAULT_LIMIT
  MAX_LIMIT = Ibsoft::ConversationDistribution::CandidateFinder::MAX_LIMIT

  def initialize(account:, user:, limit: DEFAULT_LIMIT)
    @account = account
    @user = user
    @limit = limit
  end

  def perform
    candidates = available_candidates
    marked_candidates = mark_required_candidates(candidates)

    {
      generated_at: Time.current.iso8601,
      real_assignment_enabled: Ibsoft::ConversationDistribution::ExecutionConfig.real_assignment_enabled?,
      limit: safe_limit,
      agent_entry_assignment: agent_entry_policy(marked_candidates.size).payload,
      summary: summary_payload(marked_candidates),
      auto_claim_conversation_ids: auto_claim_conversation_ids(marked_candidates),
      candidates: marked_candidates
    }
  end

  private

  attr_reader :account, :user, :limit

  def available_candidates
    candidate_conversations_array.filter_map do |conversation|
      candidate = candidate_builder.payload_for(conversation)
      decision = Ibsoft::ConversationDistribution::DecisionResolver.new(
        conversation: conversation,
        candidate: candidate
      ).perform

      next unless candidate[:eligible] && decision[:action] == Ibsoft::ConversationDistribution::DecisionResolver::ACTION_ASSIGN

      candidate.merge(decision: decision)
    end
  end

  def candidate_conversations_array
    @candidate_conversations_array ||= candidate_conversations.to_a
  end

  def candidate_conversations
    return Conversation.none if user_team_ids.blank? || user_inbox_ids.blank?
    return Conversation.none unless current_account_user&.online?

    account.conversations
           .includes(:contact, :inbox, :team)
           .open
           .unassigned
           .where(first_reply_created_at: nil, inbox_id: user_inbox_ids, team_id: user_team_ids)
           .where.not(waiting_since: nil)
           .sort_on_waiting_since
           .limit(safe_limit)
  end

  def candidate_builder
    @candidate_builder ||= Ibsoft::ConversationDistribution::AgentAssignmentCandidateBuilder.new(
      account: account,
      conversations: candidate_conversations_array
    )
  end

  def mark_required_candidates(candidates)
    sorted_candidates = candidates.sort_by { |candidate| candidate[:waiting_since].to_s }
    policy = agent_entry_policy(sorted_candidates.size)
    return [] unless policy.enabled?

    sorted_candidates.each_with_index.map do |candidate, index|
      candidate.merge(
        required: index < policy.required_count,
        preselected: index < policy.required_count,
        auto_claim: false
      )
    end
  end

  def auto_claim_conversation_ids(candidates)
    return [] unless Ibsoft::ConversationDistribution::ExecutionConfig.real_assignment_enabled?

    candidates.filter_map { |candidate| candidate[:conversation_id] if candidate[:auto_claim] }
  end

  def agent_entry_policy(candidate_count)
    @agent_entry_policy ||= {}
    @agent_entry_policy[candidate_count] ||= Ibsoft::ConversationDistribution::AgentEntryAssignmentPolicy.new(
      account: account,
      candidate_count: candidate_count
    )
  end

  def summary_payload(candidates)
    {
      scanned: candidate_conversations_array.size,
      available: candidates.size,
      required: candidates.count { |candidate| candidate[:required] },
      auto_claim: candidates.count { |candidate| candidate[:auto_claim] },
      by_team: candidates.group_by { |candidate| candidate[:team_name] }.transform_values(&:size)
    }
  end

  def current_account_user
    @current_account_user ||= account.account_users.find_by(user_id: user.id)
  end

  def user_team_ids
    @user_team_ids ||= account.teams.joins(:team_members).where(team_members: { user_id: user.id }).ids
  end

  def user_inbox_ids
    @user_inbox_ids ||= account.inboxes.joins(:inbox_members).where(inbox_members: { user_id: user.id }).ids
  end

  def safe_limit
    requested_limit = limit.to_i
    requested_limit = DEFAULT_LIMIT unless requested_limit.positive?

    [requested_limit, MAX_LIMIT].min
  end
end

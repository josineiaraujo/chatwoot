class Ibsoft::ConversationDistribution::RedistributionCandidateFinder
  DEFAULT_LIMIT = Ibsoft::ConversationDistribution::CandidateFinder::DEFAULT_LIMIT
  MAX_LIMIT = Ibsoft::ConversationDistribution::CandidateFinder::MAX_LIMIT
  REDISTRIBUTABLE_EVENT_TYPES = %w[assignment_completed redistribution_completed].freeze

  def initialize(account:, inbox_id: nil, team_id: nil, limit: DEFAULT_LIMIT)
    @account = account
    @inbox_id = inbox_id
    @team_id = team_id
    @limit = limit
  end

  def perform
    scope = Ibsoft::ConversationDistribution::EventLog
            .where(id: latest_assignment_event_ids)
            .joins(:conversation)
            .includes(:new_assignee, conversation: [:inbox, :team, :assignee])
            .where(conversations: { status: Conversation.statuses[:open], first_reply_created_at: nil })
            .where.not(conversations: { assignee_id: nil })
            .where('conversations.assignee_id = ibsoft_conversation_distribution_event_logs.new_assignee_id')

    scope = scope.where(conversations: { inbox_id: inbox_id }) if inbox_id.present?
    scope = scope.where(conversations: { team_id: team_id }) if team_id.present?

    scope.order(created_at: :asc, id: :asc).limit(safe_limit)
  end

  def safe_limit
    requested_limit = limit.to_i
    requested_limit = DEFAULT_LIMIT unless requested_limit.positive?

    [requested_limit, MAX_LIMIT].min
  end

  private

  attr_reader :account, :inbox_id, :team_id, :limit

  def latest_assignment_event_ids
    table_name = Ibsoft::ConversationDistribution::EventLog.table_name
    scope = Ibsoft::ConversationDistribution::EventLog
            .where(account: account, event_type: REDISTRIBUTABLE_EVENT_TYPES)
            .where.not(conversation_id: nil)
            .where.not(new_assignee_id: nil)

    scope = scope.where(inbox_id: inbox_id) if inbox_id.present?
    scope = scope.where(team_id: team_id) if team_id.present?

    scope
      .select("DISTINCT ON (#{table_name}.conversation_id) #{table_name}.id")
      .order(Arel.sql("#{table_name}.conversation_id, #{table_name}.created_at DESC, #{table_name}.id DESC"))
  end
end

class Ibsoft::ConversationDistribution::CandidateFinder
  DEFAULT_LIMIT = 50
  MAX_LIMIT = 100

  def initialize(account:, inbox_id: nil, team_id: nil, limit: DEFAULT_LIMIT)
    @account = account
    @inbox_id = inbox_id
    @team_id = team_id
    @limit = limit
  end

  def perform
    scope = account.conversations
                   .includes(:inbox, :team)
                   .open
                   .unassigned
                   .where(first_reply_created_at: nil)
                   .where.not(team_id: nil)

    scope = scope.where(inbox_id: inbox_id) if inbox_id.present?
    scope = scope.where(team_id: team_id) if team_id.present?

    scope.sort_on_waiting_since.limit(safe_limit)
  end

  def safe_limit
    requested_limit = limit.to_i
    requested_limit = DEFAULT_LIMIT unless requested_limit.positive?

    [requested_limit, MAX_LIMIT].min
  end

  private

  attr_reader :account, :inbox_id, :team_id, :limit
end

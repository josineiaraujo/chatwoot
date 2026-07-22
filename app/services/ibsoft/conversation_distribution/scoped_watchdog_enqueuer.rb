class Ibsoft::ConversationDistribution::ScopedWatchdogEnqueuer
  def initialize(conversation:, team:)
    @conversation = conversation
    @team = team
  end

  def perform
    Ibsoft::ConversationDistribution::WatchdogJob.perform_later(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      team_id: team.id
    )

    { enqueued: true }
  rescue StandardError => e
    Rails.logger.error(
      '[Ibsoft::ConversationDistribution] immediate scoped distribution failed ' \
      "conversation=#{conversation.id} team=#{team.id} error=#{e.class}: #{e.message}"
    )
    { enqueued: false, error: e.class.name }
  end

  private

  attr_reader :conversation, :team
end

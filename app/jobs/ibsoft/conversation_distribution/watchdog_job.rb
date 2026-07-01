class Ibsoft::ConversationDistribution::WatchdogJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform(account_id: nil, inbox_id: nil, team_id: nil, limit: nil)
    result = Ibsoft::ConversationDistribution::WatchdogRunner.new(
      account_id: account_id,
      inbox_id: inbox_id,
      team_id: team_id,
      limit: limit || Ibsoft::ConversationDistribution::ExecutionConfig.job_limit
    ).perform

    Rails.logger.info("[Ibsoft::ConversationDistribution::WatchdogJob] #{result[:summary].to_json}")
    result
  end
end

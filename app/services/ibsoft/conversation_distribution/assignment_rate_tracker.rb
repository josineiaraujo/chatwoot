class Ibsoft::ConversationDistribution::AssignmentRateTracker
  def self.track(account:, conversation:, agent:, policy:)
    Ibsoft::ConversationDistribution::AssignmentRateLimiter.new(
      account: account,
      conversation: conversation,
      agent: agent,
      policy: policy
    ).track_assignment
  end
end

class Ibsoft::ConversationDistribution::AssignmentPolicySnapshot
  def self.from_candidate(candidate)
    {
      config: {
        'distribution' => {
          'assignment_order' => candidate.dig(:policy, :assignment_order),
          'assignment_limit_mode' => candidate.dig(:policy, :assignment_limit_mode),
          'open_conversation_limit' => candidate.dig(:policy, :open_conversation_limit),
          'capacity_ignore_customer_waiting_enabled' => candidate.dig(:policy, :capacity_ignore_customer_waiting_enabled),
          'capacity_ignore_customer_waiting_minutes' => candidate.dig(:policy, :capacity_ignore_customer_waiting_minutes),
          'capacity_excluded_labels' => Array(candidate.dig(:policy, :capacity_excluded_labels)),
          'fair_distribution_limit' => candidate.dig(:policy, :fair_distribution_limit),
          'fair_distribution_window' => candidate.dig(:policy, :fair_distribution_window)
        }
      }
    }
  end

  def self.from_policy(policy)
    policy.respond_to?(:raw_policy) ? policy.raw_policy : policy
  end
end

class Ibsoft::ConversationDistribution::AssignmentRoundLimiter
  def initialize(candidates:)
    @candidates = candidates
  end

  def processable?(candidate)
    !candidate[:eligible] || processable_eligible_conversation_ids.include?(candidate[:conversation_id])
  end

  private

  attr_reader :candidates

  def processable_eligible_conversation_ids
    @processable_eligible_conversation_ids ||=
      eligible_candidates
      .group_by { |candidate| [candidate[:inbox_id], candidate[:team_id]] }
      .values
      .flat_map { |items| limited_items(items) }
      .pluck(:conversation_id)
  end

  def eligible_candidates
    candidates.select { |candidate| candidate[:eligible] }
  end

  def limited_items(items)
    return items unless round_limit_enabled?(items.first)

    items.first(round_limit_for(items.first))
  end

  def round_limit_enabled?(candidate)
    candidate.dig(:policy, :max_assignments_per_round_enabled) != false
  end

  def round_limit_for(candidate)
    limit_value = candidate.dig(:policy, :max_assignments_per_round).to_i
    limit_value.positive? ? limit_value : Ibsoft::ConversationDistribution::CandidateFinder::DEFAULT_LIMIT
  end
end

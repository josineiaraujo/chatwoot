class Ibsoft::ConversationDistribution::CandidatePrioritizer
  EARLIEST_CREATED = 'earliest_created'.freeze
  LONGEST_WAITING = 'longest_waiting'.freeze

  def initialize(candidates:)
    @candidates = candidates
  end

  def perform
    candidates.sort_by { |candidate| priority_key(candidate) }
  end

  private

  attr_reader :candidates

  def priority_key(candidate)
    case conversation_priority(candidate)
    when EARLIEST_CREATED
      [timestamp(candidate[:created_at]), timestamp(candidate[:waiting_since]), candidate[:conversation_id].to_i]
    else
      [timestamp(candidate[:waiting_since]), timestamp(candidate[:created_at]), candidate[:conversation_id].to_i]
    end
  end

  def conversation_priority(candidate)
    candidate.dig(:policy, :conversation_priority).presence || LONGEST_WAITING
  end

  def timestamp(value)
    return Time.zone.at(0) if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    Time.zone.at(0)
  end
end

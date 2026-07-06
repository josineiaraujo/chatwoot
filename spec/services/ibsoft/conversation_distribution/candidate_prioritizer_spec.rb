require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::CandidatePrioritizer do
  it 'orders candidates by waiting time when the policy uses longest_waiting' do
    candidates = [
      {
        conversation_id: 1,
        created_at: 2.hours.ago.iso8601,
        waiting_since: 5.minutes.ago.iso8601,
        policy: { conversation_priority: 'longest_waiting' }
      },
      {
        conversation_id: 2,
        created_at: 10.minutes.ago.iso8601,
        waiting_since: 1.hour.ago.iso8601,
        policy: { conversation_priority: 'longest_waiting' }
      }
    ]

    result = described_class.new(candidates: candidates).perform

    expect(result.pluck(:conversation_id)).to eq([2, 1])
  end

  it 'orders candidates by creation time when the policy uses earliest_created' do
    candidates = [
      {
        conversation_id: 1,
        created_at: 2.hours.ago.iso8601,
        waiting_since: 5.minutes.ago.iso8601,
        policy: { conversation_priority: 'earliest_created' }
      },
      {
        conversation_id: 2,
        created_at: 10.minutes.ago.iso8601,
        waiting_since: 1.hour.ago.iso8601,
        policy: { conversation_priority: 'earliest_created' }
      }
    ]

    result = described_class.new(candidates: candidates).perform

    expect(result.pluck(:conversation_id)).to eq([1, 2])
  end

  it 'keeps ordering stable for a larger candidate list' do
    candidates = Array.new(100) do |index|
      {
        conversation_id: index + 1,
        created_at: (100 - index).minutes.ago.iso8601,
        waiting_since: index.minutes.ago.iso8601,
        policy: { conversation_priority: 'earliest_created' }
      }
    end

    result = described_class.new(candidates: candidates).perform

    expect(result.pluck(:conversation_id)).to eq((1..100).to_a)
  end
end

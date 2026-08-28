require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AssignmentRoundLimiter do
  it 'limits eligible candidates by inbox and team when round limit is enabled' do
    candidates = build_candidates(
      count: 3,
      policy: {
        max_assignments_per_round_enabled: true,
        max_assignments_per_round: 1
      }
    )

    limiter = described_class.new(candidates: candidates)

    expect(processable_ids(limiter, candidates)).to eq([1])
  end

  it 'does not limit eligible candidates when round limit is disabled' do
    candidates = build_candidates(
      count: 100,
      policy: {
        max_assignments_per_round_enabled: false,
        max_assignments_per_round: 1
      }
    )

    limiter = described_class.new(candidates: candidates)

    expect(processable_ids(limiter, candidates)).to eq((1..100).to_a)
  end

  it 'keeps legacy policies limited when the enabled flag is missing' do
    candidates = build_candidates(
      count: 3,
      policy: { max_assignments_per_round: 2 }
    )

    limiter = described_class.new(candidates: candidates)

    expect(processable_ids(limiter, candidates)).to eq([1, 2])
  end

  it 'applies the limit independently for each inbox and team group' do
    candidates = build_candidates(
      count: 3,
      policy: {
        max_assignments_per_round_enabled: true,
        max_assignments_per_round: 1
      }
    ) + build_candidates(
      count: 3,
      starting_id: 10,
      inbox_id: 2,
      team_id: 2,
      policy: {
        max_assignments_per_round_enabled: true,
        max_assignments_per_round: 2
      }
    )

    limiter = described_class.new(candidates: candidates)

    expect(processable_ids(limiter, candidates)).to eq([1, 10, 11])
  end

  it 'always keeps ineligible candidates processable so they can be logged as skipped' do
    candidates = build_candidates(
      count: 2,
      policy: {
        max_assignments_per_round_enabled: true,
        max_assignments_per_round: 1
      }
    )
    candidates << {
      conversation_id: 3,
      inbox_id: 1,
      team_id: 1,
      eligible: false,
      policy: {
        max_assignments_per_round_enabled: true,
        max_assignments_per_round: 1
      }
    }

    limiter = described_class.new(candidates: candidates)

    expect(processable_ids(limiter, candidates)).to eq([1, 3])
  end

  it 'processes exactly the configured number of candidates at the boundary' do
    candidates = build_candidates(
      count: 4,
      policy: {
        max_assignments_per_round_enabled: true,
        max_assignments_per_round: 3
      }
    )

    limiter = described_class.new(candidates: candidates)

    expect(processable_ids(limiter, candidates)).to eq([1, 2, 3])
  end

  it 'uses the safe default limit when the configured limit is zero' do
    candidates = build_candidates(
      count: 55,
      policy: {
        max_assignments_per_round_enabled: true,
        max_assignments_per_round: 0
      }
    )

    limiter = described_class.new(candidates: candidates)

    expect(processable_ids(limiter, candidates)).to eq((1..50).to_a)
  end

  it 'uses the safe default limit when the configured limit is malformed' do
    candidates = build_candidates(
      count: 55,
      policy: {
        max_assignments_per_round_enabled: true,
        max_assignments_per_round: 'invalid'
      }
    )

    limiter = described_class.new(candidates: candidates)

    expect(processable_ids(limiter, candidates)).to eq((1..50).to_a)
  end

  it 'handles a list containing no eligible candidates' do
    candidates = build_candidates(count: 3, policy: {}).each { |candidate| candidate[:eligible] = false }
    limiter = described_class.new(candidates: candidates)

    expect(processable_ids(limiter, candidates)).to eq([1, 2, 3])
  end

  def processable_ids(limiter, candidates)
    candidates
      .select { |candidate| limiter.processable?(candidate) }
      .pluck(:conversation_id)
  end

  def build_candidates(count:, policy:, starting_id: 1, inbox_id: 1, team_id: 1)
    Array.new(count) do |index|
      {
        conversation_id: starting_id + index,
        inbox_id: inbox_id,
        team_id: team_id,
        eligible: true,
        policy: policy
      }
    end
  end
end

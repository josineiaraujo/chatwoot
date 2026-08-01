require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AgentCapacityGuard do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:policy) do
    {
      config: {
        'distribution' => {
          'assignment_limit_mode' => 'open_conversations',
          'open_conversation_limit' => 1
        }
      }
    }
  end

  it 'rejects the claim after rechecking a full agent inside the capacity lock' do
    create(:conversation, account: account, inbox: inbox, assignee: agent, status: 'open')

    result = described_class.new(account: account, agent: agent, policy: policy).perform do
      raise 'the assignment must not run'
    end

    expect(result).to eq(status: :capacity_reached, assignment: nil)
  end

  it 'returns the assignment created inside the protected transaction' do
    assignment = { conversation: build(:conversation), previous_assignee: nil }

    result = described_class.new(account: account, agent: agent, policy: policy).perform { assignment }

    expect(result).to eq(status: :claimed, assignment: assignment)
  end

  it 'preserves assignment window mode without applying the simultaneous conversation limit' do
    create(:conversation, account: account, inbox: inbox, assignee: agent, status: 'open')
    policy[:config]['distribution']['assignment_limit_mode'] = 'assignment_window'

    result = described_class.new(account: account, agent: agent, policy: policy).perform { :assigned }

    expect(result).to eq(status: :claimed, assignment: :assigned)
  end

  it 'serializes capacity claims for the same account and agent across database connections' do
    ready = Queue.new
    start = Queue.new
    state_lock = Mutex.new
    active_claims = 0
    assigned_count = 0
    maximum_concurrent_claims = 0
    evaluator = instance_double(Ibsoft::ConversationDistribution::AgentCapacityEvaluator)
    allow(evaluator).to receive(:within_limit?) { state_lock.synchronize { assigned_count < 1 } }
    allow(Ibsoft::ConversationDistribution::AgentCapacityEvaluator).to receive(:new).and_return(evaluator)

    threads = Array.new(2) do
      Thread.new do
        ApplicationRecord.connection_pool.with_connection do
          ready << true
          start.pop

          described_class.new(account: account, agent: agent, policy: policy).perform do
            state_lock.synchronize do
              active_claims += 1
              assigned_count += 1
              maximum_concurrent_claims = [maximum_concurrent_claims, active_claims].max
            end
            sleep 0.1
            state_lock.synchronize { active_claims -= 1 }
            :assigned
          end
        end
      end
    end

    2.times { ready.pop }
    2.times { start << true }
    results = threads.map(&:value)

    expect(maximum_concurrent_claims).to eq(1)
    expect(assigned_count).to eq(1)
    expect(results.pluck(:status)).to contain_exactly(:claimed, :capacity_reached)
  end
end

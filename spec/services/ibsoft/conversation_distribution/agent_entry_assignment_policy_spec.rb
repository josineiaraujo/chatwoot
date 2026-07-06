require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AgentEntryAssignmentPolicy do
  let(:account) { create(:account) }

  it 'calculates required conversations by percentage without capping voluntary claims' do
    create(
      :ibsoft_chathub_account_setting,
      account: account,
      config: {
        agent_entry_assignment: {
          enabled: true,
          required_percentage: 30,
          minimum_required: 1
        }
      }
    )

    policy = described_class.new(account: account, candidate_count: 50)

    expect(policy.required_count).to eq(15)
  end

  it 'respects minimum and available candidate count' do
    create(
      :ibsoft_chathub_account_setting,
      account: account,
      config: {
        agent_entry_assignment: {
          enabled: true,
          required_percentage: 10,
          minimum_required: 2
        }
      }
    )

    policy = described_class.new(account: account, candidate_count: 1)

    expect(policy.required_count).to eq(1)
  end

  it 'returns zero required conversations when disabled' do
    create(
      :ibsoft_chathub_account_setting,
      account: account,
      config: { agent_entry_assignment: { enabled: false } }
    )

    policy = described_class.new(account: account, candidate_count: 10)

    expect(policy).not_to be_enabled
    expect(policy.required_count).to eq(0)
  end
end

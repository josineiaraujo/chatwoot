require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AutomationHandoffPolicy do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }

  it 'requires a target team when enabled' do
    policy = described_class.new(account: account, inbox: inbox, enabled: true, target_team: nil)

    expect(policy).not_to be_valid
    expect(policy.errors[:target_team]).to be_present
  end

  it 'allows inactive policies without a target team' do
    policy = described_class.new(account: account, inbox: inbox, enabled: false, target_team: nil)

    expect(policy).to be_valid
  end

  it 'normalizes invalid idle time to the default value' do
    policy = described_class.create!(account: account, inbox: inbox, target_team: team, stale_after_minutes: 0)

    expect(policy.stale_after_minutes).to eq(described_class::DEFAULT_STALE_AFTER_MINUTES)
  end

  it 'does not allow the same channel twice in the same account' do
    create(:ibsoft_automation_handoff_policy, account: account, inbox: inbox, target_team: team)
    duplicate = build(:ibsoft_automation_handoff_policy, account: account, inbox: inbox, target_team: team)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:inbox_id]).to be_present
  end

  it 'rejects an inbox from another account' do
    other_inbox = create(:inbox)
    policy = build(:ibsoft_automation_handoff_policy, account: account, inbox: other_inbox, target_team: team)

    expect(policy).not_to be_valid
    expect(policy.errors[:inbox]).to be_present
  end

  it 'rejects a target team from another account' do
    other_team = create(:team)
    policy = build(:ibsoft_automation_handoff_policy, account: account, inbox: inbox, target_team: other_team)

    expect(policy).not_to be_valid
    expect(policy.errors[:target_team]).to be_present
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::ChannelPolicy do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }

  it 'is disabled with safe default config when no named policy is linked' do
    policy = described_class.create!(account: account, inbox: inbox)

    expect(policy.payload).to include(enabled: false, distribution_policy_id: nil)
    expect(policy.payload.dig(:config, 'unavailable', 'action')).to eq('wait')
    expect(policy.payload.dig(:config, 'unavailability', 'no_available_agent', 'action')).to eq('wait')
    expect(policy.payload.dig(:config, 'unavailability', 'outside_business_hours', 'action')).to eq('wait')
    expect(policy.payload.dig(:config, 'business_hours', 'mode')).to eq('inherit_channel')
    expect(policy.payload.dig(:config, 'distribution', 'max_assignments_per_round')).to eq(5)
  end

  it 'uses linked named policy values in payload' do
    named_policy = create(
      :ibsoft_distribution_policy,
      account: account,
      name: 'Comercial',
      enabled: true,
      config: { distribution: { max_assignments_per_round: 2 } }
    )
    policy = described_class.create!(account: account, inbox: inbox, distribution_policy: named_policy)

    expect(policy.payload).to include(
      enabled: true,
      distribution_policy_id: named_policy.id,
      distribution_policy_name: 'Comercial'
    )
    expect(policy.payload.dig(:config, 'distribution', 'max_assignments_per_round')).to eq(2)
  end

  it 'rejects inboxes from another account' do
    another_inbox = create(:inbox)
    policy = described_class.new(account: account, inbox: another_inbox)

    expect(policy).not_to be_valid
    expect(policy.errors[:inbox]).to include('must belong to account')
  end

  it 'rejects named policies from another account' do
    other_policy = create(:ibsoft_distribution_policy)
    policy = described_class.new(account: account, inbox: inbox, distribution_policy: other_policy)

    expect(policy).not_to be_valid
    expect(policy.errors[:distribution_policy]).to include('must belong to account')
  end
end

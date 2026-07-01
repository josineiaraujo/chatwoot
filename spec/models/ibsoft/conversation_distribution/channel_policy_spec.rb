require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::ChannelPolicy do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }

  it 'normalizes missing config with safe defaults' do
    policy = described_class.create!(account: account, inbox: inbox, config: {})

    expect(policy.effective_config.dig('unavailable', 'action')).to eq('wait')
    expect(policy.effective_config.dig('business_hours', 'mode')).to eq('inherit_channel')
    expect(policy.effective_config.dig('distribution', 'max_assignments_per_round')).to eq(5)
  end

  it 'rejects invalid fallback actions' do
    policy = described_class.new(
      account: account,
      inbox: inbox,
      config: { unavailable: { action: 'invalid' } }
    )

    expect(policy).not_to be_valid
    expect(policy.errors[:config]).to include('has invalid unavailable action')
  end

  it 'rejects inboxes from another account' do
    another_inbox = create(:inbox)
    policy = described_class.new(account: account, inbox: another_inbox)

    expect(policy).not_to be_valid
    expect(policy.errors[:inbox]).to include('must belong to account')
  end
end

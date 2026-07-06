require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::EffectivePolicyResolver do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }

  it 'returns a disabled default when no policy exists' do
    payload = described_class.new(account: account, inbox: inbox, team: team).perform

    expect(payload).to include(
      enabled: false,
      source: 'default',
      policy_type: 'default'
    )
  end

  it 'uses channel policy when team policy is not overriding it' do
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
    create(:ibsoft_distribution_team_policy, account: account, team: team, override_channel_policy: false)

    payload = described_class.new(account: account, inbox: inbox, team: team).perform

    expect(payload).to include(
      enabled: true,
      source: 'channel',
      policy_type: 'channel'
    )
  end

  it 'uses team policy when team policy overrides the channel' do
    fallback_team = create(:team, account: account)
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
    create(
      :ibsoft_distribution_team_policy,
      account: account,
      team: team,
      enabled: false,
      override_channel_policy: true,
      config: { unavailable: { action: 'fallback_team', fallback_team_id: fallback_team.id } }
    )

    payload = described_class.new(account: account, inbox: inbox, team: team).perform

    expect(payload).to include(
      enabled: false,
      source: 'team',
      policy_type: 'team'
    )
    expect(payload[:config].dig('unavailability', 'no_available_agent', 'action')).to eq('fallback_team')
    expect(payload[:config].dig('unavailability', 'outside_business_hours', 'action')).to eq('fallback_team')
  end

  it 'uses named policy linked to the team override' do
    named_policy = create(
      :ibsoft_distribution_policy,
      account: account,
      name: 'Fila critica',
      enabled: true,
      config: { distribution: { max_assignments_per_round: 1 } }
    )
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: false)
    create(
      :ibsoft_distribution_team_policy,
      account: account,
      team: team,
      override_channel_policy: true,
      distribution_policy: named_policy
    )

    payload = described_class.new(account: account, inbox: inbox, team: team).perform

    expect(payload).to include(
      enabled: true,
      source: 'team',
      distribution_policy_id: named_policy.id,
      distribution_policy_name: 'Fila critica'
    )
    expect(payload[:config].dig('distribution', 'max_assignments_per_round')).to eq(1)
  end
end

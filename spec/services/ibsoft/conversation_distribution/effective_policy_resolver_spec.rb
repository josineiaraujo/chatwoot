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

  it 'uses a global team override when there is no channel-specific team configuration' do
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: false)
    create(
      :ibsoft_distribution_team_policy,
      account: account,
      team: team,
      inbox: nil,
      enabled: true,
      override_channel_policy: true
    )

    payload = described_class.new(account: account, inbox: inbox, team: team).perform

    expect(payload).to include(enabled: true, source: 'team', policy_type: 'team')
  end

  it 'prefers a channel-specific team override over the global team override' do
    global_policy = create(:ibsoft_distribution_policy, account: account, enabled: false)
    exact_policy = create(:ibsoft_distribution_policy, account: account, enabled: true)
    create(
      :ibsoft_distribution_team_policy,
      account: account,
      team: team,
      inbox: nil,
      override_channel_policy: true,
      distribution_policy: global_policy
    )
    create(
      :ibsoft_distribution_team_policy,
      account: account,
      team: team,
      inbox: inbox,
      override_channel_policy: true,
      distribution_policy: exact_policy
    )

    payload = described_class.new(account: account, inbox: inbox, team: team).perform

    expect(payload).to include(enabled: true, source: 'team', distribution_policy_id: exact_policy.id)
  end

  it 'lets an exact non-override configuration suppress a global team override for that channel' do
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: false)
    create(
      :ibsoft_distribution_team_policy,
      account: account,
      team: team,
      inbox: nil,
      enabled: true,
      override_channel_policy: true
    )
    create(
      :ibsoft_distribution_team_policy,
      account: account,
      team: team,
      inbox: inbox,
      override_channel_policy: false
    )

    payload = described_class.new(account: account, inbox: inbox, team: team).perform

    expect(payload).to include(enabled: false, source: 'channel', policy_type: 'channel')
  end

  it 'does not resolve policies belonging to another account' do
    other_account = create(:account)
    create(:ibsoft_distribution_channel_policy, account: other_account, inbox: create(:inbox, account: other_account), enabled: true)

    payload = described_class.new(account: account, inbox: inbox, team: team).perform

    expect(payload).to include(enabled: false, source: 'default', account_id: account.id)
  end
end

FactoryBot.define do
  factory :ibsoft_distribution_channel_policy, class: 'Ibsoft::ConversationDistribution::ChannelPolicy' do
    account
    inbox { create(:inbox, account: account) }
    enabled { false }
    config { {} }
  end

  factory :ibsoft_distribution_team_policy, class: 'Ibsoft::ConversationDistribution::TeamPolicy' do
    account
    team { create(:team, account: account) }
    inbox { nil }
    enabled { false }
    override_channel_policy { false }
    config { {} }
  end
end

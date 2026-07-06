FactoryBot.define do
  factory :ibsoft_distribution_policy, class: 'Ibsoft::ConversationDistribution::Policy' do
    account
    sequence(:name) { |n| "Politica #{n}" }
    enabled { false }
    config { {} }
  end

  factory :ibsoft_distribution_channel_policy, class: 'Ibsoft::ConversationDistribution::ChannelPolicy' do
    account
    inbox { create(:inbox, account: account) }
    distribution_policy { nil }

    transient do
      enabled { nil }
      config { nil }
    end

    after(:build) do |channel_policy, evaluator|
      next if channel_policy.distribution_policy.present?
      next if evaluator.enabled.nil? && evaluator.config.nil?

      channel_policy.distribution_policy = build(
        :ibsoft_distribution_policy,
        account: channel_policy.account,
        enabled: evaluator.enabled || false,
        config: evaluator.config || {}
      )
    end
  end

  factory :ibsoft_distribution_team_policy, class: 'Ibsoft::ConversationDistribution::TeamPolicy' do
    account
    team { create(:team, account: account) }
    inbox { nil }
    override_channel_policy { false }
    distribution_policy { nil }

    transient do
      enabled { nil }
      config { nil }
    end

    after(:build) do |team_policy, evaluator|
      next if team_policy.distribution_policy.present?
      next if evaluator.enabled.nil? && evaluator.config.nil?

      team_policy.distribution_policy = build(
        :ibsoft_distribution_policy,
        account: team_policy.account,
        enabled: evaluator.enabled || false,
        config: evaluator.config || {}
      )
    end
  end
end

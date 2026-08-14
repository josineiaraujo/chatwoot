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

  factory :ibsoft_automation_handoff_policy, class: 'Ibsoft::ConversationDistribution::AutomationHandoffPolicy' do
    account
    inbox { create(:inbox, account: account) }
    target_team { create(:team, account: account) }
    enabled { true }
    stale_after_minutes { 10 }
    timeout_action { 'forward_to_team' }
    customer_message_enabled { false }
    customer_message { nil }
    close_warning_enabled { false }
    close_warning_message { nil }
    close_warning_delay_minutes { 1 }
    close_final_message_enabled { false }
    close_final_message { nil }
  end
end

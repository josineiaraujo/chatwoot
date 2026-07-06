class Ibsoft::ConversationDistribution::EffectivePolicyResolver
  pattr_initialize [:account!, :inbox!, { team: nil }]

  def perform
    return team_policy_payload if team_policy&.override_channel_policy?
    return channel_policy_payload if channel_policy

    default_payload
  end

  private

  def team_policy_payload
    team_policy.payload.merge(source: 'team')
  end

  def channel_policy_payload
    channel_policy.payload.merge(source: 'channel')
  end

  def default_payload
    {
      id: nil,
      account_id: account.id,
      inbox_id: inbox.id,
      team_id: team&.id,
      enabled: false,
      policy_type: 'default',
      source: 'default',
      config: Ibsoft::ConversationDistribution::Policy.default_config,
      created_at: nil,
      updated_at: nil
    }
  end

  def channel_policy
    @channel_policy ||= Ibsoft::ConversationDistribution::ChannelPolicy.find_by(
      account: account,
      inbox: inbox
    )
  end

  def team_policy
    return if team.blank?

    @team_policy ||= exact_team_policy || global_team_policy
  end

  def exact_team_policy
    Ibsoft::ConversationDistribution::TeamPolicy.find_by(
      account: account,
      team: team,
      inbox: inbox
    )
  end

  def global_team_policy
    Ibsoft::ConversationDistribution::TeamPolicy.find_by(
      account: account,
      team: team,
      inbox_id: nil
    )
  end
end

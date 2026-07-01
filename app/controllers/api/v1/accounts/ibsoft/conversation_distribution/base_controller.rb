class Api::V1::Accounts::Ibsoft::ConversationDistribution::BaseController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end

  def fetch_team
    @team = Current.account.teams.find(params[:team_id])
  end

  def optional_policy_inbox
    return if params[:policy_inbox_id].blank?

    @optional_policy_inbox ||= Current.account.inboxes.find(params[:policy_inbox_id])
  end

  def assign_policy_attributes(policy)
    policy.enabled = boolean_param(:enabled) if params.key?(:enabled)
    policy.config = distribution_config if params.key?(:config)
  end

  def boolean_param(key)
    ActiveModel::Type::Boolean.new.cast(params[key])
  end

  def distribution_config
    raw_config = params[:config]
    return {} if raw_config.blank?
    return raw_config.to_unsafe_h if raw_config.respond_to?(:to_unsafe_h)

    raw_config.to_h
  end
end

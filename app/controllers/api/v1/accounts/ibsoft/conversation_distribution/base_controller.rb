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

  def assign_distribution_policy(policy)
    return unless params.key?(:distribution_policy_id)

    policy.distribution_policy = distribution_policy_from_param
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

  def distribution_policy_from_param
    return if params[:distribution_policy_id].blank?

    Ibsoft::ConversationDistribution::Policy.find_by!(account: Current.account, id: params[:distribution_policy_id])
  end
end

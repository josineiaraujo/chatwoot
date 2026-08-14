class Api::V1::Accounts::Ibsoft::ConversationDistribution::AutomationHandoffPoliciesController <
  Api::V1::Accounts::Ibsoft::ConversationDistribution::BaseController
  POLICY_ATTRIBUTE_KEYS = %i[
    enabled
    stale_after_minutes
    timeout_action
    target_team_id
    customer_message_enabled
    customer_message
    close_warning_enabled
    close_warning_message
    close_warning_delay_minutes
    close_final_message_enabled
    close_final_message
  ].freeze
  BOOLEAN_ATTRIBUTE_KEYS = %i[
    enabled
    customer_message_enabled
    close_warning_enabled
    close_final_message_enabled
  ].freeze

  before_action :fetch_inbox

  def show
    render json: policy.payload
  end

  def update
    policy.update!(policy_attributes)

    render json: policy.payload
  end

  private

  def policy
    @policy ||= Ibsoft::ConversationDistribution::AutomationHandoffPolicy.find_or_initialize_by(
      account: Current.account,
      inbox: @inbox
    )
  end

  def policy_attributes
    attrs = params.permit(*POLICY_ATTRIBUTE_KEYS).to_h.symbolize_keys
    normalize_boolean_attributes!(attrs)
    normalize_target_team!(attrs)
    attrs
  end

  def normalize_boolean_attributes!(attrs)
    BOOLEAN_ATTRIBUTE_KEYS.each do |attribute|
      attrs[attribute] = boolean_param(attribute) if attrs.key?(attribute)
    end
  end

  def normalize_target_team!(attrs)
    return unless attrs.key?(:target_team_id)

    attrs.delete(:target_team_id)
    attrs[:target_team] = target_team_from_param
  end

  def target_team_from_param
    return if params[:target_team_id].blank?

    Current.account.teams.find(params[:target_team_id])
  end
end

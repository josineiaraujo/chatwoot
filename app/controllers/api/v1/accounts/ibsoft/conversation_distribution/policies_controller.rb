class Api::V1::Accounts::Ibsoft::ConversationDistribution::PoliciesController <
  Api::V1::Accounts::Ibsoft::ConversationDistribution::BaseController
  before_action :set_policy, only: [:show, :update, :destroy]

  def index
    render json: {
      policies: policies.map(&:payload)
    }
  end

  def show
    render json: @policy.payload
  end

  def create
    policy = Ibsoft::ConversationDistribution::Policy.new(policy_attributes.merge(account: Current.account))
    policy.save!

    render json: policy.payload
  end

  def update
    @policy.update!(policy_attributes)

    render json: @policy.payload
  end

  def destroy
    @policy.destroy!

    head :no_content
  end

  private

  def policies
    Ibsoft::ConversationDistribution::Policy.where(account: Current.account).order(:name)
  end

  def set_policy
    @policy = Ibsoft::ConversationDistribution::Policy.find_by!(account: Current.account, id: params[:id])
  end

  def policy_attributes
    attrs = {}
    attrs[:name] = params[:name] if params.key?(:name)
    attrs[:enabled] = boolean_param(:enabled) if params.key?(:enabled)
    attrs[:config] = distribution_config if params.key?(:config)
    attrs[:after_hours_policy] = after_hours_policy_from_param if params.key?(:after_hours_policy_id)
    attrs
  end

  def after_hours_policy_from_param
    return if params[:after_hours_policy_id].blank?

    Ibsoft::AfterHours::Policy.find_by!(account: Current.account, id: params[:after_hours_policy_id])
  end
end

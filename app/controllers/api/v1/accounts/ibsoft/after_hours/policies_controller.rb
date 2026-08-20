class Api::V1::Accounts::Ibsoft::AfterHours::PoliciesController < Api::V1::Accounts::Ibsoft::AfterHours::BaseController
  before_action :set_policy, only: [:show, :update, :destroy]

  def index
    render json: { policies: policy_scope.includes(:distribution_policies).order(:name).map(&:payload) }
  end

  def show
    render json: @policy.payload
  end

  def create
    policy = policy_scope.create!(policy_attributes)
    render json: policy.payload
  end

  def update
    @policy.update!(policy_attributes)
    render json: @policy.payload
  end

  def destroy
    destroyer = Ibsoft::AfterHours::PolicyDestroyer.new(policy: @policy)
    return head :no_content if destroyer.perform

    render json: {
      message: @policy.errors.full_messages.join(', '),
      attributes: @policy.errors.attribute_names
    }, status: :unprocessable_content
  end

  private

  def set_policy
    @policy = policy_scope.find(params[:id])
  end

  def policy_attributes
    params.permit(
      :name,
      :enabled,
      :exit_command,
      :regular_message,
      :holiday_message,
      :exit_confirmation_message
    )
  end
end

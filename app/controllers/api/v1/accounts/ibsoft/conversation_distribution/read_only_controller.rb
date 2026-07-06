class Api::V1::Accounts::Ibsoft::ConversationDistribution::ReadOnlyController < Api::V1::Accounts::BaseController
  before_action :check_ibsoft_distribution_read_authorization?

  private

  def check_ibsoft_distribution_read_authorization?
    return if Ibsoft::ConversationDistribution::SupervisorPermission.can_read?(Current.account_user)

    raise Pundit::NotAuthorizedError
  end
end

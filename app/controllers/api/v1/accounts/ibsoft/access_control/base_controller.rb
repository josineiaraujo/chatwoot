class Api::V1::Accounts::Ibsoft::AccessControl::BaseController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization!

  private

  def check_admin_authorization!
    return if Current.account_user&.administrator?

    raise Pundit::NotAuthorizedError
  end
end

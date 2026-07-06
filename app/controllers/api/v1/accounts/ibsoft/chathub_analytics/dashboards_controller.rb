class Api::V1::Accounts::Ibsoft::ChathubAnalytics::DashboardsController <
  Api::V1::Accounts::Ibsoft::ChathubAnalytics::BaseController
  before_action :check_agent_dashboard_authorization!, only: [:agent]
  before_action :check_supervisor_dashboard_authorization!, only: [:supervisor]

  def agent
    render json: Ibsoft::ChathubAnalytics::AgentDashboard.new(
      account: Current.account,
      user: Current.user,
      filters: dashboard_filters
    ).perform
  end

  def supervisor
    render json: Ibsoft::ChathubAnalytics::SupervisorDashboard.new(
      account: Current.account,
      filters: dashboard_filters
    ).perform
  end

  private

  def check_agent_dashboard_authorization!
    return if Ibsoft::ChathubAnalytics::Permission.can_read_agent?(Current.account_user)

    raise Pundit::NotAuthorizedError
  end

  def check_supervisor_dashboard_authorization!
    return if Ibsoft::ChathubAnalytics::Permission.can_read_supervisor?(Current.account_user)

    raise Pundit::NotAuthorizedError
  end
end

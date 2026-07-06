class Api::V1::Accounts::Ibsoft::ChathubAnalytics::BaseController < Api::V1::Accounts::BaseController
  private

  def dashboard_filters
    params.permit(:period, :since, :until, :inbox_id, :team_id)
  end
end

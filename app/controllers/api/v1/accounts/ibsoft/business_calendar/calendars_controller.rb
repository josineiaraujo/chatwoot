class Api::V1::Accounts::Ibsoft::BusinessCalendar::CalendarsController <
  Api::V1::Accounts::Ibsoft::BusinessCalendar::BaseController
  before_action :set_calendar, only: [:show, :update, :destroy]

  def index
    calendars = calendar_scope.includes(:holidays, :team_links).order(:name)
    render json: { calendars: calendars.map(&:payload) }
  end

  def show
    render json: @calendar.payload(include_holidays: true)
  end

  def create
    calendar = calendar_scope.create!(name: params.require(:name))
    render json: calendar.payload(include_holidays: true)
  end

  def update
    @calendar.update!(name: params.require(:name))
    render json: @calendar.payload(include_holidays: true)
  end

  def destroy
    @calendar.destroy!
    head :no_content
  end
end

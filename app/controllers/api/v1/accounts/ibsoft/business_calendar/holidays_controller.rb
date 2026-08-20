class Api::V1::Accounts::Ibsoft::BusinessCalendar::HolidaysController <
  Api::V1::Accounts::Ibsoft::BusinessCalendar::BaseController
  before_action :set_calendar
  before_action :set_holiday, only: [:update, :destroy]

  def index
    render json: { holidays: @calendar.holidays.order(:holiday_date, :name).map(&:payload) }
  end

  def create
    holiday = @calendar.holidays.create!(manual_attributes)
    render json: holiday.payload
  end

  def update
    @holiday.update!(manual_attributes)
    render json: @holiday.payload
  end

  def destroy
    @holiday.destroy!
    head :no_content
  end

  private

  def set_holiday
    @holiday = @calendar.holidays.find(params[:id])
  end

  def manual_attributes
    {
      holiday_date: params.require(:holiday_date),
      name: params.require(:name),
      holiday_kind: params.fetch(:holiday_kind, 'holiday'),
      source: 'manual',
      source_scope: 'manual',
      state_code: nil
    }
  end
end

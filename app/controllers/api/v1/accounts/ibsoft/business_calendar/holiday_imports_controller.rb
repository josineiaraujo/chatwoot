class Api::V1::Accounts::Ibsoft::BusinessCalendar::HolidayImportsController <
  Api::V1::Accounts::Ibsoft::BusinessCalendar::BaseController
  before_action :set_calendar

  def preview
    render json: importer.preview
  rescue Ibsoft::BusinessCalendar::InvertextoClient::RequestError, ArgumentError => e
    render json: { error: 'invertexto_request_failed', reason: e.message }, status: :unprocessable_content
  end

  def create
    render json: importer.import
  rescue Ibsoft::BusinessCalendar::InvertextoClient::RequestError, ArgumentError => e
    render json: { error: 'invertexto_request_failed', reason: e.message }, status: :unprocessable_content
  end

  private

  def importer
    @importer ||= Ibsoft::BusinessCalendar::HolidayImporter.new(
      calendar: @calendar,
      year: params.require(:year),
      import_options: {
        state_code: params[:state_code],
        include_optional: params[:include_optional],
        holiday_dates: params[:holiday_dates]
      }
    )
  end
end

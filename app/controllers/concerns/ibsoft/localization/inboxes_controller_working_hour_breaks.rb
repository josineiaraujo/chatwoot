# frozen_string_literal: true

module Ibsoft::Localization::InboxesControllerWorkingHourBreaks
  def update
    super
    update_ibsoft_working_hour_breaks
  end

  private

  def update_ibsoft_working_hour_breaks
    return unless params.key?(:ibsoft_working_hour_breaks)

    permitted = params.permit(
      ibsoft_working_hour_breaks: Ibsoft::Localization::WorkingHourBreak::PERMITTED_PARAMS
    )
    @inbox.update_ibsoft_working_hour_breaks(
      permitted[:ibsoft_working_hour_breaks] || []
    )
  end
end

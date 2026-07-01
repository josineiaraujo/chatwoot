# frozen_string_literal: true

module Ibsoft::Localization::WorkingHourBreakAware
  def open_at?(time)
    super && !inbox.in_ibsoft_working_hour_break?(time)
  end
end

# frozen_string_literal: true

module Ibsoft::Localization::AccountDefaultTimezone
  extend ActiveSupport::Concern

  included do
    before_validation :set_ibsoft_default_reporting_timezone
  end

  private

  def set_ibsoft_default_reporting_timezone
    self.settings ||= {}
    return if reporting_timezone.present?

    self.reporting_timezone = Ibsoft::Localization::DefaultTimezone.value
  end
end

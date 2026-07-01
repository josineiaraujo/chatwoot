# frozen_string_literal: true

Rails.application.config.to_prepare do
  Account.include Ibsoft::Localization::AccountDefaultTimezone unless Account.included_modules.include?(Ibsoft::Localization::AccountDefaultTimezone)

  Inbox.include Ibsoft::Localization::InboxWorkingHourBreaks unless Inbox.included_modules.include?(Ibsoft::Localization::InboxWorkingHourBreaks)

  WorkingHour.prepend Ibsoft::Localization::WorkingHourBreakAware unless Ibsoft::Localization::WorkingHourBreakAware <= WorkingHour

  return if Ibsoft::Localization::InboxesControllerWorkingHourBreaks <= Api::V1::Accounts::InboxesController

  Api::V1::Accounts::InboxesController.prepend Ibsoft::Localization::InboxesControllerWorkingHourBreaks
end

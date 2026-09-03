# frozen_string_literal: true

Rails.autoloaders.main.on_load('Account') do |account|
  extension = Ibsoft::Localization::AccountDefaultTimezone
  account.include(extension) unless account.ancestors.include?(extension)
end

Rails.autoloaders.main.on_load('Inbox') do |inbox|
  extension = Ibsoft::Localization::InboxWorkingHourBreaks
  inbox.include(extension) unless inbox.ancestors.include?(extension)
end

Rails.autoloaders.main.on_load('WorkingHour') do |working_hour|
  extension = Ibsoft::Localization::WorkingHourBreakAware
  working_hour.prepend(extension) unless working_hour.ancestors.include?(extension)
end

Rails.autoloaders.main.on_load('Api::V1::Accounts::InboxesController') do |controller|
  extension = Ibsoft::Localization::InboxesControllerWorkingHourBreaks
  controller.prepend(extension) unless controller.ancestors.include?(extension)
end

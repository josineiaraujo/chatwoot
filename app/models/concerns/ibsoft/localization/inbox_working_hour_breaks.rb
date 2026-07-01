# frozen_string_literal: true

module Ibsoft::Localization::InboxWorkingHourBreaks
  extend ActiveSupport::Concern

  included do
    has_many :ibsoft_working_hour_breaks,
             class_name: 'Ibsoft::Localization::WorkingHourBreak',
             dependent: :destroy_async
  end

  def ibsoft_working_hour_breaks_schedule
    ibsoft_working_hour_breaks.ordered.map(&:schedule_attributes)
  end

  def update_ibsoft_working_hour_breaks(params)
    normalized_breaks = Array(params).filter_map do |working_hour_break|
      normalized_working_hour_break(working_hour_break)
    end

    Ibsoft::Localization::WorkingHourBreak.transaction do
      ibsoft_working_hour_breaks.destroy_all
      normalized_breaks.each do |attributes|
        ibsoft_working_hour_breaks.create!(attributes)
      end
    end

    update_account_cache
  end

  def in_ibsoft_working_hour_break?(time)
    inbox_time = time.in_time_zone(timezone)
    ibsoft_working_hour_breaks
      .where(day_of_week: inbox_time.to_date.wday)
      .any? { |working_hour_break| working_hour_break.contains?(inbox_time) }
  end

  private

  def normalized_working_hour_break(working_hour_break)
    attributes = working_hour_break.to_h.slice(*Ibsoft::Localization::WorkingHourBreak::PERMITTED_PARAMS)
    return if attributes.blank?

    attributes
  end
end

# frozen_string_literal: true

# == Schema Information
#
# Table name: ibsoft_working_hour_breaks
#
#  id            :bigint           not null, primary key
#  day_of_week   :integer          not null
#  end_hour      :integer          not null
#  end_minutes   :integer          not null
#  start_hour    :integer          not null
#  start_minutes :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  inbox_id      :bigint           not null
#
# Indexes
#
#  idx_ibsoft_working_hour_breaks_on_inbox_day     (inbox_id,day_of_week)
#  index_ibsoft_working_hour_breaks_on_account_id  (account_id)
#  index_ibsoft_working_hour_breaks_on_inbox_id    (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#
class Ibsoft::Localization::WorkingHourBreak < ApplicationRecord
  self.table_name = 'ibsoft_working_hour_breaks'

  PERMITTED_PARAMS = %w[day_of_week start_hour start_minutes end_hour end_minutes].freeze

  belongs_to :account
  belongs_to :inbox

  before_validation :assign_account

  validates :day_of_week, presence: true, inclusion: 0..6
  validates :start_hour, :end_hour, presence: true, inclusion: 0..23
  validates :start_minutes, :end_minutes, presence: true, inclusion: 0..59
  validate :end_after_start

  scope :ordered, -> { order(:day_of_week, :start_hour, :start_minutes, :id) }

  def schedule_attributes
    {
      'day_of_week' => day_of_week,
      'start_hour' => start_hour,
      'start_minutes' => start_minutes,
      'end_hour' => end_hour,
      'end_minutes' => end_minutes
    }
  end

  def contains?(time)
    minutes = (time.hour * 60) + time.min
    minutes >= start_total_minutes && minutes < end_total_minutes
  end

  private

  def assign_account
    self.account_id ||= inbox&.account_id
  end

  def end_after_start
    return if start_total_minutes < end_total_minutes

    errors.add(
      :end_hour,
      I18n.t('ibsoft_localization.working_hour_break.errors.end_after_start')
    )
  end

  def start_total_minutes
    (start_hour.to_i * 60) + start_minutes.to_i
  end

  def end_total_minutes
    (end_hour.to_i * 60) + end_minutes.to_i
  end
end

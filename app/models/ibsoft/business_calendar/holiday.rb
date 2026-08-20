# == Schema Information
#
# Table name: ibsoft_business_holidays
#
#  id                   :bigint           not null, primary key
#  holiday_date         :date             not null
#  holiday_kind         :string           default("holiday"), not null
#  name                 :string           not null
#  source               :string           default("manual"), not null
#  source_scope         :string           default("manual"), not null
#  state_code           :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  business_calendar_id :bigint           not null
#
# Indexes
#
#  idx_ibsoft_business_holidays_calendar       (business_calendar_id)
#  idx_ibsoft_business_holidays_calendar_date  (business_calendar_id,holiday_date) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (business_calendar_id => ibsoft_business_calendars.id) ON DELETE => cascade
#
class Ibsoft::BusinessCalendar::Holiday < ApplicationRecord
  self.table_name = 'ibsoft_business_holidays'

  KINDS = %w[holiday optional].freeze
  SOURCES = %w[manual invertexto].freeze
  SOURCE_SCOPES = %w[manual national state].freeze

  belongs_to :business_calendar,
             class_name: 'Ibsoft::BusinessCalendar::Calendar',
             inverse_of: :holidays

  validates :holiday_date, :name, presence: true
  validates :holiday_date, uniqueness: { scope: :business_calendar_id }
  validates :holiday_kind, inclusion: { in: KINDS }
  validates :source, inclusion: { in: SOURCES }
  validates :source_scope, inclusion: { in: SOURCE_SCOPES }
  validates :state_code, format: { with: /\A[A-Z]{2}\z/ }, allow_blank: true

  after_commit :invalidate_lookup_cache

  def account_id
    business_calendar.account_id
  end

  def payload
    {
      id: id,
      holiday_date: holiday_date,
      name: name,
      holiday_kind: holiday_kind,
      source: source,
      source_scope: source_scope,
      state_code: state_code,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def invalidate_lookup_cache
    dates = [holiday_date, previous_changes.dig('holiday_date', 0)].compact.uniq
    dates.each { |date| Ibsoft::BusinessCalendar::Cache.invalidate_holiday(business_calendar_id, date) }
  end
end

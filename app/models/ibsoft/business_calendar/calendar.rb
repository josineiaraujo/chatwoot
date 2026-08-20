# == Schema Information
#
# Table name: ibsoft_business_calendars
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  idx_ibsoft_business_calendars_account_name     (account_id,name) UNIQUE
#  index_ibsoft_business_calendars_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#
class Ibsoft::BusinessCalendar::Calendar < ApplicationRecord
  self.table_name = 'ibsoft_business_calendars'

  belongs_to :account
  has_many :holidays,
           class_name: 'Ibsoft::BusinessCalendar::Holiday',
           foreign_key: :business_calendar_id,
           inverse_of: :business_calendar,
           dependent: :destroy
  has_many :team_links,
           class_name: 'Ibsoft::BusinessCalendar::TeamLink',
           foreign_key: :business_calendar_id,
           inverse_of: :business_calendar,
           dependent: :destroy
  has_many :teams, through: :team_links

  validates :name, presence: true, uniqueness: { scope: :account_id }

  def payload(include_holidays: false)
    data = {
      id: id,
      account_id: account_id,
      name: name,
      holiday_count: holidays.size,
      team_ids: team_links.map(&:team_id),
      created_at: created_at,
      updated_at: updated_at
    }
    data[:holidays] = holidays.order(:holiday_date, :name).map(&:payload) if include_holidays
    data
  end
end

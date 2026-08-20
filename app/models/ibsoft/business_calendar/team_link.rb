# == Schema Information
#
# Table name: ibsoft_business_calendar_team_links
#
#  id                   :bigint           not null, primary key
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  business_calendar_id :bigint           not null
#  team_id              :bigint           not null
#
# Indexes
#
#  idx_ibsoft_calendar_team_links_account_team              (account_id,team_id) UNIQUE
#  idx_ibsoft_calendar_team_links_calendar                  (business_calendar_id)
#  index_ibsoft_business_calendar_team_links_on_account_id  (account_id)
#  index_ibsoft_business_calendar_team_links_on_team_id     (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (business_calendar_id => ibsoft_business_calendars.id) ON DELETE => cascade
#  fk_rails_...  (team_id => teams.id) ON DELETE => cascade
#
class Ibsoft::BusinessCalendar::TeamLink < ApplicationRecord
  self.table_name = 'ibsoft_business_calendar_team_links'

  belongs_to :account
  belongs_to :team
  belongs_to :business_calendar,
             class_name: 'Ibsoft::BusinessCalendar::Calendar',
             inverse_of: :team_links

  validates :team_id, uniqueness: { scope: :account_id }
  validate :records_belong_to_account

  after_commit :invalidate_lookup_cache

  def payload
    {
      team_id: team_id,
      business_calendar_id: business_calendar_id,
      business_calendar_name: business_calendar.name
    }
  end

  private

  def records_belong_to_account
    errors.add(:team, :invalid) if team.present? && team.account_id != account_id
    return unless business_calendar.present? && business_calendar.account_id != account_id

    errors.add(:business_calendar, :invalid)
  end

  def invalidate_lookup_cache
    Ibsoft::BusinessCalendar::Cache.invalidate_team(account_id, team_id)
  end
end

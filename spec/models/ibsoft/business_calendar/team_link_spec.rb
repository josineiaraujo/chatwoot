require 'rails_helper'

RSpec.describe Ibsoft::BusinessCalendar::TeamLink do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:calendar) { create(:ibsoft_business_calendar, account: account) }

  before { Rails.cache.clear }

  it 'allows only one calendar link for a department in the account' do
    create(:ibsoft_business_calendar_team_link, account: account, team: team, business_calendar: calendar)
    duplicate = build(
      :ibsoft_business_calendar_team_link,
      account: account,
      team: team,
      business_calendar: create(:ibsoft_business_calendar, account: account)
    )

    expect(duplicate).not_to be_valid
  end

  it 'rejects a department or calendar from another account' do
    other_account = create(:account)
    other_team = create(:team, account: other_account)
    other_calendar = create(:ibsoft_business_calendar, account: other_account)

    wrong_team_link = build(
      :ibsoft_business_calendar_team_link,
      account: account,
      team: other_team,
      business_calendar: calendar
    )
    wrong_calendar_link = build(
      :ibsoft_business_calendar_team_link,
      account: account,
      team: team,
      business_calendar: other_calendar
    )

    expect(wrong_team_link).not_to be_valid
    expect(wrong_calendar_link).not_to be_valid
  end

  it 'invalidates the department lookup after create, update and destroy' do
    expect(Ibsoft::BusinessCalendar::Cache.calendar_id_for_team(account.id, team.id)).to be_nil

    link = create(:ibsoft_business_calendar_team_link, account: account, team: team, business_calendar: calendar)
    expect(Ibsoft::BusinessCalendar::Cache.calendar_id_for_team(account.id, team.id)).to eq(calendar.id)

    replacement = create(:ibsoft_business_calendar, account: account)
    link.update!(business_calendar: replacement)
    expect(Ibsoft::BusinessCalendar::Cache.calendar_id_for_team(account.id, team.id)).to eq(replacement.id)

    link.destroy!
    expect(Ibsoft::BusinessCalendar::Cache.calendar_id_for_team(account.id, team.id)).to be_nil
  end
end

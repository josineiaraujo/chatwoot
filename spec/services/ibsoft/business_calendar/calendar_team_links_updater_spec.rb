require 'rails_helper'

RSpec.describe Ibsoft::BusinessCalendar::CalendarTeamLinksUpdater do
  let(:account) { create(:account) }
  let(:calendar) { create(:ibsoft_business_calendar, account: account) }
  let(:first_team) { create(:team, account: account) }
  let(:second_team) { create(:team, account: account) }

  before { Rails.cache.clear }

  it 'replaces the calendar links with normalized unique department ids' do
    stale_team = create(:team, account: account)
    stale_link = create(
      :ibsoft_business_calendar_team_link,
      account: account,
      team: stale_team,
      business_calendar: calendar
    )

    result = described_class.new(
      account: account,
      calendar: calendar,
      team_ids: [second_team.id.to_s, first_team.id, second_team.id]
    ).perform

    expect(result.team_links.pluck(:team_id)).to contain_exactly(first_team.id, second_team.id)
    expect(Ibsoft::BusinessCalendar::TeamLink.exists?(stale_link.id)).to be(false)
  end

  it 'moves a department atomically from another calendar' do
    previous_calendar = create(:ibsoft_business_calendar, account: account)
    link = create(
      :ibsoft_business_calendar_team_link,
      account: account,
      team: first_team,
      business_calendar: previous_calendar
    )

    described_class.new(account: account, calendar: calendar, team_ids: [first_team.id]).perform

    expect(link.reload.business_calendar).to eq(calendar)
    expect(Ibsoft::BusinessCalendar::Cache.calendar_id_for_team(account.id, first_team.id)).to eq(calendar.id)
  end

  it 'removes every link when the selection is empty' do
    create(:ibsoft_business_calendar_team_link, account: account, team: first_team, business_calendar: calendar)

    described_class.new(account: account, calendar: calendar, team_ids: []).perform

    expect(calendar.team_links.reload).to be_empty
  end

  it 'rejects invalid ids without changing existing links' do
    link = create(:ibsoft_business_calendar_team_link, account: account, team: first_team, business_calendar: calendar)

    expect do
      described_class.new(account: account, calendar: calendar, team_ids: [second_team.id, 'invalid']).perform
    end.to raise_error(ActiveRecord::RecordNotFound)

    expect(link.reload.business_calendar).to eq(calendar)
    expect(calendar.team_links.pluck(:team_id)).to eq([first_team.id])
  end

  it 'rejects a department from another account without partial updates' do
    existing_link = create(
      :ibsoft_business_calendar_team_link,
      account: account,
      team: first_team,
      business_calendar: calendar
    )
    other_team = create(:team)

    expect do
      described_class.new(account: account, calendar: calendar, team_ids: [second_team.id, other_team.id]).perform
    end.to raise_error(ActiveRecord::RecordNotFound)

    expect(existing_link.reload.business_calendar).to eq(calendar)
    expect(calendar.team_links.pluck(:team_id)).to eq([first_team.id])
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::BusinessCalendar::TeamLinkUpdater do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:calendar) { create(:ibsoft_business_calendar, account: account) }

  before { Rails.cache.clear }

  it 'creates and replaces the calendar linked to a department' do
    created = described_class.new(
      account: account,
      team: team,
      business_calendar_id: calendar.id
    ).perform
    replacement = create(:ibsoft_business_calendar, account: account)
    updated = described_class.new(
      account: account,
      team: team,
      business_calendar_id: replacement.id
    ).perform

    expect(created.team).to eq(team)
    expect(updated.reload.business_calendar).to eq(replacement)
    expect(Ibsoft::BusinessCalendar::TeamLink.where(account: account, team: team).count).to eq(1)
  end

  it 'removes the link when the calendar id is blank' do
    create(:ibsoft_business_calendar_team_link, account: account, team: team, business_calendar: calendar)

    result = described_class.new(account: account, team: team, business_calendar_id: nil).perform

    expect(result).to be_nil
    expect(Ibsoft::BusinessCalendar::TeamLink.exists?(account: account, team: team)).to be(false)
  end

  it 'rejects a calendar from another account and preserves the current link' do
    link = create(:ibsoft_business_calendar_team_link, account: account, team: team, business_calendar: calendar)
    other_calendar = create(:ibsoft_business_calendar)

    expect do
      described_class.new(
        account: account,
        team: team,
        business_calendar_id: other_calendar.id
      ).perform
    end.to raise_error(ActiveRecord::RecordNotFound)

    expect(link.reload.business_calendar).to eq(calendar)
  end

  it 'rejects a department from another account' do
    other_team = create(:team)

    expect do
      described_class.new(account: account, team: other_team, business_calendar_id: calendar.id).perform
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end

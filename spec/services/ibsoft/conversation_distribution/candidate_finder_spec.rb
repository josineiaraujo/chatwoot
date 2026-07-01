require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::CandidateFinder do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }

  it 'returns open unassigned team conversations that still need first human reply' do
    eligible = create(:conversation, account: account, inbox: inbox, team: team, waiting_since: 10.minutes.ago)
    agent = create(:user, account: account)
    create(:team_member, team: team, user: agent)
    create(:conversation, account: account, inbox: inbox, team: team, assignee: agent)
    create(:conversation, account: account, inbox: inbox, status: :resolved, team: team)
    create(:conversation, account: account, inbox: inbox, team: team, first_reply_created_at: 5.minutes.ago)
    create(:conversation, account: account, inbox: inbox, team: nil)

    result = described_class.new(account: account).perform

    expect(result).to contain_exactly(eligible)
  end

  it 'caps the preview limit' do
    3.times do
      create(:conversation, account: account, inbox: inbox, team: team)
    end

    result = described_class.new(account: account, limit: 2).perform

    expect(result.length).to eq(2)
  end
end

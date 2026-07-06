require 'rails_helper'

RSpec.describe Ibsoft::ChathubAnalytics::AgentDashboard do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account, name: 'Comercial') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, team: team, assignee: agent) }

  it 'returns own response and redistribution metrics grouped by team' do
    conversation.update!(status: :open, assignee: agent)

    create(
      :reporting_event,
      account: account,
      inbox: inbox,
      user: agent,
      conversation: conversation,
      name: 'reply_time',
      value: 120,
      event_end_time: 1.day.ago
    )
    create(
      :reporting_event,
      account: account,
      inbox: inbox,
      user: agent,
      conversation: conversation,
      name: 'conversation_resolved',
      value: 600,
      event_end_time: 1.day.ago
    )
    create(
      :ibsoft_distribution_event_log,
      account: account,
      inbox: inbox,
      team: team,
      conversation: conversation,
      event_type: 'redistribution_completed',
      previous_assignee: agent,
      created_at: 1.day.ago
    )

    result = described_class.new(account: account, user: agent).perform

    expect(result.dig(:summary, :average_reply_seconds)).to eq(120)
    expect(result.dig(:summary, :resolved_count)).to eq(1)
    expect(result.dig(:summary, :redistributions_away_count)).to eq(1)
    expect(result.dig(:summary, :redistribution_basis_count)).to eq(2)
    expect(result.dig(:by_team, 0)).to include(
      team_id: team.id,
      team_name: team.reload.name,
      open_assigned: 1,
      average_reply_seconds: 120,
      resolved_count: 1,
      redistributions_away_count: 1
    )
  end
end

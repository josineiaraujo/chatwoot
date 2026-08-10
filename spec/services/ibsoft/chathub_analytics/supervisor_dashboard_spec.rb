require 'rails_helper'

RSpec.describe Ibsoft::ChathubAnalytics::SupervisorDashboard do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account, name: 'Suporte') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, team: team, assignee: agent) }

  it 'returns operation summaries and agent rankings for the account' do
    conversation.update!(status: :open, assignee: agent)

    create(
      :reporting_event,
      account: account,
      inbox: inbox,
      user: agent,
      conversation: conversation,
      name: 'first_response',
      value: 180,
      event_end_time: 1.day.ago
    )
    create(
      :reporting_event,
      account: account,
      inbox: inbox,
      user: agent,
      conversation: conversation,
      name: 'conversation_resolved',
      value: 900,
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

    result = described_class.new(account: account).perform

    expect(result.dig(:summary, :average_first_response_seconds)).to eq(180)
    expect(result.dig(:summary, :average_resolution_seconds)).to eq(900)
    expect(result.dig(:summary, :redistributions_count)).to eq(1)
    expect(result.dig(:summary, :redistribution_basis_count)).to eq(1)
    expect(result.dig(:top_agents, 0)).to include(
      agent_id: agent.id,
      resolved_count: 1,
      total_handled: 2
    )
    expect(result.dig(:redistribution_ranking, 0)).to include(
      agent_id: agent.id,
      redistributions_count: 1
    )
  end

  it 'does not leak events from another account' do
    other_account = create(:account)
    other_agent = create(:user, account: other_account)
    other_conversation = create(:conversation, account: other_account, assignee: other_agent)
    create(
      :reporting_event,
      account: other_account,
      user: other_agent,
      conversation: other_conversation,
      name: 'first_response',
      value: 99,
      event_end_time: 1.day.ago
    )

    result = described_class.new(account: account).perform

    expect(result.dig(:summary, :average_first_response_seconds)).to eq(0)
    expect(result[:top_agents]).to be_empty
  end

  it 'limits slow first response ranking to ten agents' do
    12.times do |index|
      current_agent = create(:user, account: account)
      current_conversation = create(:conversation, account: account, inbox: inbox, assignee: current_agent)
      create(
        :reporting_event,
        account: account,
        inbox: inbox,
        user: current_agent,
        conversation: current_conversation,
        name: 'first_response',
        value: (index + 1) * 60,
        event_end_time: 1.day.ago
      )
    end

    result = described_class.new(account: account).perform

    expect(result[:slow_response_ranking].length).to eq(10)
    expect(result.dig(:slow_response_ranking, 0, :average_first_response_seconds)).to eq(720)
    expect(result.dig(:slow_response_ranking, 9, :average_first_response_seconds)).to eq(180)
  end

  it 'does not count AgentBot-owned conversations as unassigned human work' do
    create(:conversation, account: account, inbox: inbox, team: team, status: :open, assignee: nil)
    create(
      :conversation,
      account: account,
      inbox: inbox,
      team: team,
      status: :open,
      assignee_agent_bot: create(:agent_bot, account: account)
    )

    result = described_class.new(account: account).perform
    team_result = result[:by_team].find { |item| item[:team_id] == team.id }

    expect(result.dig(:summary, :open_conversations)).to eq(2)
    expect(result.dig(:summary, :unassigned_conversations)).to eq(1)
    expect(team_result[:unassigned_count]).to eq(1)
  end
end

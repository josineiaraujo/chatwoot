require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::RedistributionCandidateFinder do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:agent) { create(:user, account: account) }

  it 'returns only the latest distribution event for open assigned conversations awaiting a first reply' do
    eligible = create(
      :conversation,
      account: account,
      inbox: inbox,
      team: team,
      assignee: agent,
      status: :open,
      first_reply_created_at: nil
    )
    old_event = create_event(conversation: eligible, assignee: agent, created_at: 30.minutes.ago)
    latest_event = create_event(
      conversation: eligible,
      assignee: agent,
      event_type: 'redistribution_completed',
      created_at: 20.minutes.ago
    )

    resolved = create(:conversation, account: account, inbox: inbox, team: team, assignee: agent, status: :resolved)
    replied = create(
      :conversation,
      account: account,
      inbox: inbox,
      team: team,
      assignee: agent,
      status: :open,
      first_reply_created_at: 5.minutes.ago
    )
    unassigned = create(:conversation, account: account, inbox: inbox, team: team, assignee: nil, status: :open)
    [resolved, replied].each { |conversation| create_event(conversation: conversation, assignee: agent) }
    create_event(conversation: unassigned, assignee: agent, synchronize_assignee: false)

    result = described_class.new(account: account).perform

    expect(result).to contain_exactly(latest_event)
    expect(result).not_to include(old_event)
  end

  it 'excludes a conversation whose current assignee differs from the latest distribution event' do
    manually_assigned_agent = create(:user, account: account)
    conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      team: team,
      assignee: manually_assigned_agent,
      status: :open
    )
    conversation.update!(assignee: manually_assigned_agent)
    create_event(conversation: conversation, assignee: agent, synchronize_assignee: false)

    expect(described_class.new(account: account).perform).to be_empty
  end

  it 'isolates candidates by account and applies inbox and team filters together' do
    selected = create(:conversation, account: account, inbox: inbox, team: team, assignee: agent, status: :open)
    selected_event = create_event(conversation: selected, assignee: agent)

    another_inbox = create(:inbox, account: account)
    another_team = create(:team, account: account)
    inbox_mismatch = create(:conversation, account: account, inbox: another_inbox, team: team, assignee: agent, status: :open)
    team_mismatch = create(:conversation, account: account, inbox: inbox, team: another_team, assignee: agent, status: :open)
    create_event(conversation: inbox_mismatch, assignee: agent)
    create_event(conversation: team_mismatch, assignee: agent)

    other_account = create(:account)
    other_inbox = create(:inbox, account: other_account)
    other_team = create(:team, account: other_account)
    other_agent = create(:user, account: other_account)
    other_conversation = create(
      :conversation,
      account: other_account,
      inbox: other_inbox,
      team: other_team,
      assignee: other_agent,
      status: :open
    )
    create_event(conversation: other_conversation, assignee: other_agent)

    result = described_class.new(account: account, inbox_id: inbox.id, team_id: team.id).perform

    expect(result).to contain_exactly(selected_event)
  end

  it 'ignores events that do not represent a completed distribution' do
    conversation = create(:conversation, account: account, inbox: inbox, team: team, assignee: agent, status: :open)
    create_event(conversation: conversation, assignee: agent, event_type: 'assignment_skipped')

    expect(described_class.new(account: account).perform).to be_empty
  end

  it 'orders the oldest waiting distribution events first and respects the requested limit' do
    newest = create_candidate_event(created_at: 10.minutes.ago)
    oldest = create_candidate_event(created_at: 30.minutes.ago)
    middle = create_candidate_event(created_at: 20.minutes.ago)

    result = described_class.new(account: account, limit: 2).perform

    expect(result).to eq([oldest, middle])
    expect(result).not_to include(newest)
  end

  it 'normalizes invalid and excessive limits' do
    expect(described_class.new(account: account, limit: 0).safe_limit).to eq(described_class::DEFAULT_LIMIT)
    expect(described_class.new(account: account, limit: -1).safe_limit).to eq(described_class::DEFAULT_LIMIT)
    expect(described_class.new(account: account, limit: described_class::MAX_LIMIT + 1).safe_limit)
      .to eq(described_class::MAX_LIMIT)
  end

  def create_candidate_event(created_at:)
    conversation = create(:conversation, account: account, inbox: inbox, team: team, assignee: agent, status: :open)
    create_event(conversation: conversation, assignee: agent, created_at: created_at)
  end

  def create_event(
    conversation:,
    assignee:,
    event_type: 'assignment_completed',
    created_at: 15.minutes.ago,
    synchronize_assignee: true
  )
    conversation.update!(assignee: assignee) if synchronize_assignee

    Ibsoft::ConversationDistribution::EventLog.create!(
      account: conversation.account,
      conversation: conversation,
      inbox: conversation.inbox,
      team: conversation.team,
      new_assignee: assignee,
      event_type: event_type,
      reason: 'test',
      metadata: {},
      created_at: created_at,
      updated_at: created_at
    )
  end
end

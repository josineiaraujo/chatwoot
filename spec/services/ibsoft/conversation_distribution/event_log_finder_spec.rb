require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::EventLogFinder do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, team: team) }

  it 'returns event logs ordered by most recent first' do
    older_event = create(
      :ibsoft_distribution_event_log,
      account: account,
      inbox: inbox,
      team: team,
      conversation: conversation,
      created_at: 2.hours.ago
    )
    newer_event = create(
      :ibsoft_distribution_event_log,
      account: account,
      inbox: inbox,
      team: team,
      conversation: conversation,
      event_type: 'redistribution_completed',
      created_at: 1.hour.ago
    )

    result = described_class.new(account: account).perform

    expect(result.dig(:summary, :total)).to eq(2)
    expect(result[:events].pluck(:id)).to eq([newer_event.id, older_event.id])
  end

  it 'filters by event type, reason, team and inbox' do
    matching_event = create(
      :ibsoft_distribution_event_log,
      account: account,
      inbox: inbox,
      team: team,
      conversation: conversation,
      event_type: 'assignment_skipped',
      reason: 'no_available_agent'
    )
    create(:ibsoft_distribution_event_log, account: account, event_type: 'assignment_completed')

    result = described_class.new(
      account: account,
      filters: {
        event_type: 'assignment_skipped',
        reason: 'no_available_agent',
        inbox_id: inbox.id,
        team_id: team.id
      }
    ).perform

    expect(result.dig(:summary, :total)).to eq(1)
    expect(result.dig(:events, 0)).to include(
      id: matching_event.id,
      event_type: 'assignment_skipped',
      reason: 'no_available_agent'
    )
  end

  it 'filters by the visible conversation display id' do
    matching_conversation = create(:conversation, account: account, inbox: inbox, team: team)
    matching_event = create(
      :ibsoft_distribution_event_log,
      account: account,
      inbox: inbox,
      team: team,
      conversation: matching_conversation
    )
    create(:ibsoft_distribution_event_log, account: account)

    result = described_class.new(
      account: account,
      filters: { conversation_id: matching_conversation.display_id }
    ).perform

    expect(result.dig(:summary, :total)).to eq(1)
    expect(result.dig(:events, 0)).to include(id: matching_event.id)
    expect(result.dig(:events, 0, :conversation)).to include(display_id: matching_conversation.display_id)
  end

  it 'filters by the visible conversation display id when pasted with a hash prefix' do
    matching_event = create(
      :ibsoft_distribution_event_log,
      account: account,
      inbox: inbox,
      team: team,
      conversation: conversation
    )
    create(:ibsoft_distribution_event_log, account: account)

    result = described_class.new(
      account: account,
      filters: { conversation_id: "##{conversation.display_id}" }
    ).perform

    expect(result.dig(:summary, :total)).to eq(1)
    expect(result.dig(:events, 0)).to include(id: matching_event.id)
  end

  it 'keeps compatibility with filtering by the internal conversation id' do
    matching_event = create(
      :ibsoft_distribution_event_log,
      account: account,
      inbox: inbox,
      team: team,
      conversation: conversation
    )
    create(:ibsoft_distribution_event_log, account: account)

    result = described_class.new(
      account: account,
      filters: { conversation_id: conversation.id }
    ).perform

    expect(result.dig(:summary, :total)).to eq(1)
    expect(result.dig(:events, 0)).to include(id: matching_event.id)
  end

  it 'includes conversation contact data in event payloads' do
    conversation.contact.update!(name: 'Jane Cliente')
    create(
      :ibsoft_distribution_event_log,
      account: account,
      inbox: inbox,
      team: team,
      conversation: conversation
    )

    result = described_class.new(account: account).perform

    expect(result.dig(:events, 0, :conversation, :contact)).to include(
      id: conversation.contact.id,
      name: 'Jane Cliente',
      email: conversation.contact.email
    )
  end

  it 'paginates results with a capped limit' do
    create_list(:ibsoft_distribution_event_log, 3, account: account)

    result = described_class.new(account: account, filters: { limit: 2, page: 2 }).perform

    expect(result[:events].size).to eq(1)
    expect(result[:pagination]).to include(
      page: 2,
      limit: 2,
      total_count: 3,
      total_pages: 2,
      next_page: nil,
      previous_page: 1
    )
  end

  it 'does not leak events from another account' do
    other_account = create(:account)
    create(:ibsoft_distribution_event_log, account: account)
    create(:ibsoft_distribution_event_log, account: other_account)

    result = described_class.new(account: account).perform

    expect(result.dig(:summary, :total)).to eq(1)
    expect(result[:events].pluck(:id)).to contain_exactly(
      Ibsoft::ConversationDistribution::EventLog.find_by!(account: account).id
    )
  end
end

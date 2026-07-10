require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AutomationHandoffExecutor do
  let(:account) { create(:account, locale: 'pt_BR') }
  let(:inbox) { create(:inbox, account: account) }
  let(:source_team) { create(:team, account: account, name: 'Automação') }
  let(:target_team) { create(:team, account: account, name: 'Suporte') }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:conversation) do
    create(
      :conversation,
      account: account,
      inbox: inbox,
      team: source_team,
      status: :pending,
      assignee_agent_bot: agent_bot,
      last_activity_at: 20.minutes.ago,
      waiting_since: 20.minutes.ago
    )
  end

  before do
    create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
    create(
      :ibsoft_automation_handoff_policy,
      account: account,
      inbox: inbox,
      target_team: target_team,
      stale_after_minutes: 10
    )
    conversation
  end

  it 'only logs the skipped event when real assignment is disabled' do
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(false)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, handoffed: 0, skipped: 1)
    expect(conversation.reload).to have_attributes(
      status: 'pending',
      team_id: source_team.id,
      assignee_agent_bot_id: agent_bot.id
    )
    expect(Ibsoft::ConversationDistribution::EventLog.last).to have_attributes(
      conversation_id: conversation.id,
      event_type: 'automation_handoff_skipped',
      reason: 'real_assignment_disabled'
    )
  end

  it 'opens and forwards the conversation to the target team when enabled', :aggregate_failures do
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = nil
    perform_enqueued_jobs(only: Conversations::ActivityMessageJob) do
      result = described_class.new(account: account).perform
    end

    expect(result[:summary]).to include(scanned: 1, handoffed: 1, skipped: 0)
    expect(conversation.reload).to have_attributes(
      status: 'open',
      team_id: target_team.id,
      assignee_id: nil,
      assignee_agent_bot_id: nil
    )
    expect(conversation.additional_attributes).to include(
      'ibsoft_distribution_source' => 'system_team_transfer',
      'ibsoft_distribution_source_reason' => 'automation_stalled',
      'ibsoft_automation_handoff_target_team_id' => target_team.id
    )
    expect(conversation.messages.activity.last.content).to eq(
      "Atendimento encaminhado automaticamente da automação para #{target_team.reload.name} por inatividade."
    )
    expect(conversation.messages.template).to be_empty

    event = Ibsoft::ConversationDistribution::EventLog.last
    expect(event).to have_attributes(
      conversation_id: conversation.id,
      event_type: 'automation_handoff_completed',
      reason: 'automation_stalled',
      team_id: target_team.id
    )
    expect(event.metadata.dig('previous_team', 'id')).to eq(source_team.id)
    expect(event.metadata.dig('target_team', 'id')).to eq(target_team.id)
    expect(event.metadata.dig('activity_message', 'status')).to eq('enqueued')
    expect(event.metadata.dig('customer_message', 'status')).to eq('disabled')
  end

  it 'sends the optional public message when configured' do
    policy = Ibsoft::ConversationDistribution::AutomationHandoffPolicy.find_by!(account: account, inbox: inbox)
    policy.update!(
      customer_message_enabled: true,
      customer_message: 'Vou encaminhar seu atendimento para nossa equipe.'
    )
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    described_class.new(account: account).perform

    message = conversation.reload.messages.template.last
    expect(message.content).to eq('Vou encaminhar seu atendimento para nossa equipe.')
    expect(message.private).to be(false)
    expect(message.content_attributes['ibsoft_conversation_distribution']).to include(
      'action' => 'automation_handoff',
      'reason' => 'automation_stalled',
      'target_team_id' => target_team.id
    )
  end

  it 'does not process the same stalled activity twice' do
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    described_class.new(account: account).perform
    conversation.update!(status: :pending, assignee: nil, assignee_agent_bot: agent_bot)

    expect { described_class.new(account: account).perform }.not_to change(
      Ibsoft::ConversationDistribution::EventLog.where(event_type: 'automation_handoff_completed'),
      :count
    )
  end
end

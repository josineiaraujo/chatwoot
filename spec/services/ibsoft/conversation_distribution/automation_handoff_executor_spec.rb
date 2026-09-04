require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AutomationHandoffExecutor do
  let(:account) { create(:account, locale: 'pt_BR') }
  let(:inbox) { create(:inbox, account: account) }
  let(:source_team) { create(:team, account: account, name: 'Automação') }
  let(:target_team) { create(:team, account: account, name: 'Suporte') }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:conversation) do
    conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      team: source_team,
      status: :pending,
      waiting_since: 20.minutes.ago
    )
    owner_attribute = conversation.respond_to?(:ai_assignee=) ? :ai_assignee : :assignee_agent_bot
    conversation.update!(owner_attribute => agent_bot)
    conversation
  end
  let(:policy) do
    create(
      :ibsoft_automation_handoff_policy,
      account: account,
      inbox: inbox,
      target_team: target_team,
      stale_after_minutes: 10
    )
  end
  let(:last_bot_message) do
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: agent_bot,
      message_type: :outgoing,
      created_at: 20.minutes.ago
    )
  end

  before do
    create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
    policy
    last_bot_message
  end

  it 'only logs the skipped event when real assignment is disabled' do
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(false)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, handoffed: 0, closed: 0, skipped: 1)
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

    expect(result[:summary]).to include(scanned: 1, handoffed: 1, closed: 0, skipped: 0)
    expect(conversation.reload).to have_attributes(
      status: 'open',
      team_id: target_team.id,
      assignee_id: nil,
      assignee_agent_bot_id: nil
    )
    expect(conversation.ai_assignee).to be_nil if conversation.respond_to?(:ai_assignee)
    expect(conversation.ai_assignee_type).to be_nil if conversation.has_attribute?(:ai_assignee_type)
    expect(conversation.waiting_since).to be_within(1.second).of(last_bot_message.created_at)
    expect(conversation.additional_attributes).to include(
      'ibsoft_distribution_source' => 'system_team_transfer',
      'ibsoft_distribution_source_reason' => 'automation_stalled',
      'ibsoft_automation_handoff_target_team_id' => target_team.id,
      'ibsoft_automation_last_bot_message_id' => last_bot_message.id
    )
    expect(conversation.messages.activity.pluck(:content)).to include(
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
    expect(event.metadata.dig('candidate', 'last_bot_message_id')).to eq(last_bot_message.id)
    expect(event.metadata.dig('previous_team', 'id')).to eq(source_team.id)
    expect(event.metadata.dig('target_team', 'id')).to eq(target_team.id)
    expect(event.metadata.dig('activity_message', 'status')).to eq('enqueued')
    expect(event.metadata.dig('customer_message', 'status')).to eq('disabled')
  end

  it 'closes the conversation without requiring a target team', :aggregate_failures do
    policy.update!(timeout_action: 'close_conversation', target_team: nil)
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = nil
    perform_enqueued_jobs(only: Conversations::ActivityMessageJob) do
      result = described_class.new(account: account).perform
    end

    expect(result[:summary]).to include(scanned: 1, handoffed: 0, closed: 1, skipped: 0)
    expect(conversation.reload).to have_attributes(
      status: 'resolved',
      team_id: source_team.id,
      assignee_id: nil,
      assignee_agent_bot_id: nil
    )
    expect(conversation.ai_assignee).to be_nil if conversation.respond_to?(:ai_assignee)
    expect(conversation.ai_assignee_type).to be_nil if conversation.has_attribute?(:ai_assignee_type)
    expect(conversation.additional_attributes).to include(
      'ibsoft_automation_close_policy_id' => policy.id,
      'ibsoft_automation_last_bot_message_id' => last_bot_message.id
    )
    expect(conversation.additional_attributes).not_to have_key('ibsoft_distribution_source')
    expect(conversation.messages.activity.pluck(:content)).to include(
      'Atendimento encerrado automaticamente após 10 minutos aguardando a resposta do cliente ' \
      'à última mensagem da automação.'
    )

    event = Ibsoft::ConversationDistribution::EventLog.last
    expect(event).to have_attributes(
      conversation_id: conversation.id,
      event_type: 'automation_close_completed',
      reason: 'automation_stalled'
    )
    expect(event.metadata['target_team']).to be_nil
  end

  it 'sends the optional public message with the selected action metadata' do
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
      'action' => 'forward_to_team',
      'reason' => 'automation_stalled',
      'target_team_id' => target_team.id
    )
  end

  it 'keeps the conversation resolved after sending the optional close message' do
    policy.update!(
      timeout_action: 'close_conversation',
      target_team: nil,
      close_final_message_enabled: true,
      close_final_message: 'Encerramos este atendimento por falta de resposta.'
    )
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    described_class.new(account: account).perform

    message = conversation.reload.messages.template.last
    expect(conversation).to have_attributes(status: 'resolved', assignee_agent_bot_id: nil)
    expect(message).to have_attributes(
      content: 'Encerramos este atendimento por falta de resposta.',
      private: false
    )
    expect(message.content_attributes['ibsoft_conversation_distribution']).to include(
      'action' => 'close_conversation',
      'reason' => 'automation_stalled',
      'target_team_id' => nil
    )
  end

  it 'warns the customer and persists a scheduled close instead of closing immediately', :aggregate_failures do
    policy.update!(
      timeout_action: 'close_conversation',
      target_team: nil,
      close_warning_enabled: true,
      close_warning_delay_minutes: 3
    )
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    schedule = Ibsoft::ConversationDistribution::AutomationCloseSchedule.find_by!(conversation: conversation)
    warning = conversation.reload.messages.template.find(schedule.warning_message_id)
    expect(result[:summary]).to include(scanned: 1, handoffed: 0, closed: 0, warnings_sent: 1, skipped: 0)
    expect(conversation).to have_attributes(status: 'pending', assignee_agent_bot_id: agent_bot.id)
    expect(warning.content).to eq('Você ainda está aí? Seu atendimento será encerrado em 3 minutos.')
    expect(schedule).to have_attributes(
      trigger_message_id: last_bot_message.id,
      expected_team_id: source_team.id,
      expected_agent_bot_id: agent_bot.id
    )
    expect(schedule.expected_policy_updated_at).to be_within(0.001.seconds).of(policy.reload.updated_at)
    expect(schedule.close_at).to be_within(1.second).of(3.minutes.from_now)
    expect(Ibsoft::ConversationDistribution::AutomationCloseJob).to have_been_enqueued
      .with(schedule.id)
      .on_queue('scheduled_jobs')
    expect(Ibsoft::ConversationDistribution::EventLog.last).to have_attributes(
      event_type: 'automation_close_warning_sent',
      reason: 'automation_stalled'
    )
  end

  it 'does not send another warning while the persistent close schedule is active' do
    policy.update!(
      timeout_action: 'close_conversation',
      target_team: nil,
      close_warning_enabled: true
    )
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    described_class.new(account: account).perform

    expect do
      result = described_class.new(account: account).perform
      expect(result[:summary]).to include(scanned: 0, warnings_sent: 0, closed: 0, skipped: 0)
    end.to not_change(
      Ibsoft::ConversationDistribution::AutomationCloseSchedule.where(conversation: conversation),
      :count
    ).and not_change(
      conversation.messages.template,
      :count
    ).and not_change(
      Ibsoft::ConversationDistribution::EventLog.where(event_type: 'automation_close_warning_sent'),
      :count
    )
  end

  it 'does not schedule a close when the warning cannot be created' do
    policy.update!(
      timeout_action: 'close_conversation',
      target_team: nil,
      close_warning_enabled: true
    )
    notifier = instance_double(
      Ibsoft::ConversationDistribution::AutomationCustomerMessageNotifier,
      perform: { applied: false, status: 'error', error: 'StandardError' }
    )
    allow(Ibsoft::ConversationDistribution::AutomationCustomerMessageNotifier).to receive(:new).and_return(notifier)
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, warnings_sent: 0, closed: 0, skipped: 1)
    expect(Ibsoft::ConversationDistribution::AutomationCloseSchedule.where(conversation: conversation)).to be_empty
    expect(conversation.reload).to be_pending
    expect(Ibsoft::ConversationDistribution::EventLog.last).to have_attributes(
      event_type: 'automation_handoff_skipped',
      reason: 'warning_delivery_failed'
    )
  end

  it 'keeps the persistent schedule when enqueueing the delayed job fails' do
    policy.update!(
      timeout_action: 'close_conversation',
      target_team: nil,
      close_warning_enabled: true
    )
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)
    allow(Ibsoft::ConversationDistribution::AutomationCloseJob).to receive(:set).and_raise(StandardError, 'queue unavailable')

    expect { described_class.new(account: account).perform }.not_to raise_error
    expect(Ibsoft::ConversationDistribution::AutomationCloseSchedule.where(conversation: conversation)).to exist
    expect(conversation.reload).to be_pending
  end

  it 'does not act on a stale candidate after the customer replies' do
    candidate = Ibsoft::ConversationDistribution::AutomationHandoffCandidateFinder.new(account: account).perform.first
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      message_type: :incoming,
      created_at: Time.current
    )
    finder = instance_double(
      Ibsoft::ConversationDistribution::AutomationHandoffCandidateFinder,
      perform: [candidate],
      safe_limit: 50
    )
    executor = described_class.new(account: account)
    allow(executor).to receive(:candidate_finder).and_return(finder)
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = executor.perform

    expect(result[:summary]).to include(scanned: 1, handoffed: 0, closed: 0, skipped: 1)
    expect(conversation.reload).to have_attributes(status: 'pending', team_id: source_team.id)
    expect(Ibsoft::ConversationDistribution::EventLog.last).to have_attributes(
      event_type: 'automation_handoff_skipped',
      reason: 'candidate_already_changed'
    )
  end

  it 'does not process the same bot waiting period twice' do
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    described_class.new(account: account).perform
    attributes = { status: :pending, assignee: nil }
    owner_attribute = conversation.respond_to?(:ai_assignee=) ? :ai_assignee : :assignee_agent_bot
    attributes[owner_attribute] = agent_bot
    conversation.update!(attributes)

    expect { described_class.new(account: account).perform }.not_to change(
      Ibsoft::ConversationDistribution::EventLog.where(event_type: 'automation_handoff_completed'),
      :count
    )
  end

  it 'does not act when the policy is disabled after candidate discovery' do
    candidate = Ibsoft::ConversationDistribution::AutomationHandoffCandidateFinder.new(account: account).perform.first
    policy.update!(enabled: false)
    finder = instance_double(
      Ibsoft::ConversationDistribution::AutomationHandoffCandidateFinder,
      perform: [candidate],
      safe_limit: 50
    )
    executor = described_class.new(account: account)
    allow(executor).to receive(:candidate_finder).and_return(finder)
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = executor.perform

    expect(result[:summary]).to include(scanned: 1, handoffed: 0, closed: 0, skipped: 1)
    expect(conversation.reload).to have_attributes(status: 'pending', team_id: source_team.id)
    expect(Ibsoft::ConversationDistribution::EventLog.last).to have_attributes(
      event_type: 'automation_handoff_skipped',
      reason: 'candidate_already_changed'
    )
  end

  it 'does not act when a forwarding policy loses its target after candidate discovery' do
    candidate = Ibsoft::ConversationDistribution::AutomationHandoffCandidateFinder.new(account: account).perform.first
    # Simulates legacy/corrupted data that cannot be created through model validations.
    policy.update_column(:target_team_id, nil) # rubocop:disable Rails/SkipsModelValidations
    finder = instance_double(
      Ibsoft::ConversationDistribution::AutomationHandoffCandidateFinder,
      perform: [candidate],
      safe_limit: 50
    )
    executor = described_class.new(account: account)
    allow(executor).to receive(:candidate_finder).and_return(finder)
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = executor.perform

    expect(result[:summary]).to include(scanned: 1, handoffed: 0, closed: 0, skipped: 1)
    expect(conversation.reload).to have_attributes(status: 'pending', team_id: source_team.id)
  end

  it 'does not fail the batch when a candidate conversation is deleted before execution' do
    candidate = Ibsoft::ConversationDistribution::AutomationHandoffCandidateFinder.new(account: account).perform.first
    conversation.destroy!
    finder = instance_double(
      Ibsoft::ConversationDistribution::AutomationHandoffCandidateFinder,
      perform: [candidate],
      safe_limit: 50
    )
    executor = described_class.new(account: account)
    allow(executor).to receive(:candidate_finder).and_return(finder)
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

    result = executor.perform

    expect(result[:summary]).to include(scanned: 1, handoffed: 0, closed: 0, skipped: 1)
    expect(result[:results].first).to include(status: 'skipped', reason: 'candidate_already_changed')
  end
end

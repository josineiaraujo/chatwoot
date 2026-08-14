require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AutomationCloseExecutor do
  let(:account) { create(:account, locale: 'pt_BR') }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:conversation) do
    create(
      :conversation,
      account: account,
      inbox: inbox,
      team: team,
      status: :pending,
      assignee_agent_bot: agent_bot,
      waiting_since: 20.minutes.ago
    )
  end
  let(:policy) do
    create(
      :ibsoft_automation_handoff_policy,
      account: account,
      inbox: inbox,
      timeout_action: 'close_conversation',
      target_team: nil,
      stale_after_minutes: 10,
      close_warning_enabled: true,
      close_warning_delay_minutes: 1,
      close_final_message_enabled: true,
      close_final_message: 'Atendimento encerrado.'
    )
  end
  let(:trigger_message) do
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
  let(:warning_message) do
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      message_type: :template,
      content: 'Você ainda está aí?',
      content_attributes: {
        ibsoft_conversation_distribution: {
          action: 'close_warning',
          reason: 'automation_stalled'
        }
      },
      created_at: 2.minutes.ago
    )
  end
  let(:schedule) do
    Ibsoft::ConversationDistribution::AutomationCloseSchedule.create!(
      account: account,
      conversation: conversation,
      automation_handoff_policy: policy,
      trigger_message_id: trigger_message.id,
      warning_message_id: warning_message.id,
      expected_team_id: conversation.team_id,
      expected_agent_bot_id: conversation.assignee_agent_bot_id,
      expected_policy_updated_at: policy.updated_at,
      close_at: 1.minute.ago
    )
  end

  before do
    create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
    schedule
  end

  it 'closes a due conversation and removes its persistent schedule', :aggregate_failures do
    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, closed: 1, cancelled: 0, skipped: 0)
    expect(conversation.reload).to have_attributes(status: 'resolved', assignee_agent_bot_id: nil)
    expect(conversation.additional_attributes).to include(
      'ibsoft_automation_close_policy_id' => policy.id,
      'ibsoft_automation_last_bot_message_id' => trigger_message.id
    )
    expect(Ibsoft::ConversationDistribution::AutomationCloseSchedule.exists?(schedule.id)).to be(false)
    expect(conversation.messages.template.reorder(:created_at, :id).last.content).to eq('Atendimento encerrado.')
    expect(Ibsoft::ConversationDistribution::EventLog.last).to have_attributes(
      conversation_id: conversation.id,
      event_type: 'automation_close_completed',
      reason: 'automation_stalled'
    )
  end

  it 'does not process an explicit schedule before its close time' do
    schedule.update!(close_at: 1.minute.from_now)

    result = described_class.new(account: account, schedule_id: schedule.id).perform

    expect(result[:summary]).to include(scanned: 1, closed: 0, cancelled: 0, ignored: 1)
    expect(result[:results].first).to include(status: 'pending', reason: 'close_not_due')
    expect(conversation.reload).to be_pending
    expect(schedule.reload).to be_present
  end

  it 'cancels the closure when the customer replies after the warning' do
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      message_type: :incoming,
      created_at: 30.seconds.ago
    )

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, closed: 0, cancelled: 1)
    expect(result[:results].first).to include(status: 'cancelled', reason: 'customer_replied')
    expect(conversation.reload).to be_pending
    expect(Ibsoft::ConversationDistribution::AutomationCloseSchedule.exists?(schedule.id)).to be(false)
    expect(Ibsoft::ConversationDistribution::EventLog.last).to have_attributes(
      event_type: 'automation_close_cancelled',
      reason: 'customer_replied'
    )
  end

  it 'cancels the closure when routing changes while the warning is pending' do
    conversation.update!(team: create(:team, account: account))

    result = described_class.new(account: account).perform

    expect(result[:results].first).to include(status: 'cancelled', reason: 'conversation_changed')
    expect(conversation.reload).to be_pending
    expect(Ibsoft::ConversationDistribution::AutomationCloseSchedule.exists?(schedule.id)).to be(false)
  end

  it 'cancels the closure when an administrator changes the policy' do
    policy.update!(close_final_message: 'Nova mensagem final.')

    result = described_class.new(account: account).perform

    expect(result[:results].first).to include(status: 'cancelled', reason: 'conversation_changed')
    expect(conversation.reload).to be_pending
    expect(Ibsoft::ConversationDistribution::AutomationCloseSchedule.exists?(schedule.id)).to be(false)
  end

  it 'cancels the closure when the warning could not be delivered' do
    warning_message.update!(status: :failed)

    result = described_class.new(account: account).perform

    expect(result[:results].first).to include(status: 'cancelled', reason: 'warning_delivery_failed')
    expect(conversation.reload).to be_pending
    expect(Ibsoft::ConversationDistribution::AutomationCloseSchedule.exists?(schedule.id)).to be(false)
  end

  it 'cancels the closure when the warning message was deleted' do
    warning_message.destroy!

    result = described_class.new(account: account).perform

    expect(result[:results].first).to include(status: 'cancelled', reason: 'conversation_changed')
    expect(conversation.reload).to be_pending
    expect(Ibsoft::ConversationDistribution::AutomationCloseSchedule.exists?(schedule.id)).to be(false)
  end

  it 'cancels the closure when the warning metadata was changed' do
    warning_message.update!(content_attributes: {})

    result = described_class.new(account: account).perform

    expect(result[:results].first).to include(status: 'cancelled', reason: 'conversation_changed')
    expect(conversation.reload).to be_pending
    expect(Ibsoft::ConversationDistribution::AutomationCloseSchedule.exists?(schedule.id)).to be(false)
  end

  it 'cancels the closure when another public message supersedes the warning' do
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: agent_bot,
      message_type: :outgoing,
      created_at: 30.seconds.ago
    )

    result = described_class.new(account: account).perform

    expect(result[:results].first).to include(status: 'cancelled', reason: 'conversation_changed')
    expect(conversation.reload).to be_pending
  end

  it 'does not process a schedule through another account' do
    result = described_class.new(account: create(:account), schedule_id: schedule.id).perform

    expect(result[:summary]).to include(scanned: 0, closed: 0, cancelled: 0)
    expect(schedule.reload).to be_present
    expect(conversation.reload).to be_pending
  end

  it 'keeps the conversation closed when the final customer message fails', :aggregate_failures do
    notifier = instance_double(
      Ibsoft::ConversationDistribution::AutomationCustomerMessageNotifier,
      perform: { applied: false, status: 'error', error: 'StandardError' }
    )
    allow(Ibsoft::ConversationDistribution::AutomationCustomerMessageNotifier).to receive(:new).with(
      conversation: conversation,
      policy: policy,
      phase: :close_final
    ).and_return(notifier)

    result = described_class.new(account: account).perform

    expect(result[:summary]).to include(closed: 1, cancelled: 0)
    expect(conversation.reload).to be_resolved
    expect(Ibsoft::ConversationDistribution::EventLog.last.metadata['customer_message']).to include(
      'applied' => false,
      'status' => 'error',
      'error' => 'StandardError'
    )
  end

  it 'is idempotent after a schedule has been completed' do
    described_class.new(account: account).perform

    expect do
      result = described_class.new(account: account, schedule_id: schedule.id).perform
      expect(result[:summary]).to include(scanned: 0, closed: 0, cancelled: 0)
    end.not_to change(
      Ibsoft::ConversationDistribution::EventLog.where(event_type: 'automation_close_completed'),
      :count
    )
  end
end

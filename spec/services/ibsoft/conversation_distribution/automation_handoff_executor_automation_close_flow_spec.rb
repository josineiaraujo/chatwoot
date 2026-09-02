require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AutomationHandoffExecutor do
  let(:account) { create(:account, locale: 'pt_BR') }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:conversation) do
    conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      team: team,
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
      timeout_action: 'close_conversation',
      target_team: nil,
      stale_after_minutes: 10,
      close_warning_enabled: true,
      close_warning_delay_minutes: 1,
      close_final_message_enabled: true,
      close_final_message: 'Atendimento encerrado.'
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
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)
  end

  it 'warns and closes the conversation when the customer does not reply', :aggregate_failures do
    schedule = schedule_warning!
    warning = conversation.messages.find(schedule.warning_message_id)

    result = run_due_close(schedule)

    expect(result[:summary]).to include(scanned: 1, closed: 1, cancelled: 0)
    expect(conversation.reload).to have_attributes(status: 'resolved', assignee_agent_bot_id: nil)
    expect(conversation.ai_assignee).to be_nil if conversation.respond_to?(:ai_assignee)
    expect(conversation.ai_assignee_type).to be_nil if conversation.has_attribute?(:ai_assignee_type)
    expect(conversation.messages.template.pluck(:content)).to include(
      warning.content,
      'Atendimento encerrado.'
    )
    expect(Ibsoft::ConversationDistribution::AutomationCloseSchedule.exists?(schedule.id)).to be(false)
  end

  it 'keeps the conversation open when the customer replies after the warning', :aggregate_failures do
    schedule = schedule_warning!
    warning = conversation.messages.find(schedule.warning_message_id)
    create_customer_reply(created_at: warning.created_at + 1.second)

    result = run_due_close(schedule)

    expect(result[:summary]).to include(scanned: 1, closed: 0, cancelled: 1)
    expect(result[:results].first).to include(status: 'cancelled', reason: 'customer_replied')
    expect(conversation.reload).to be_pending
    expect(conversation.messages.template.pluck(:content)).not_to include('Atendimento encerrado.')
  end

  it 'recognizes a customer reply created at the same timestamp as the warning' do
    schedule = schedule_warning!
    warning = conversation.messages.find(schedule.warning_message_id)
    reply = create_customer_reply(created_at: warning.created_at)

    expect(reply.id).to be > warning.id

    result = run_due_close(schedule)

    expect(result[:results].first).to include(status: 'cancelled', reason: 'customer_replied')
    expect(conversation.reload).to be_pending
  end

  it 'closes normally when an agent adds a private note after the warning' do
    schedule = schedule_warning!
    warning = conversation.messages.find(schedule.warning_message_id)
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: create(:user, account: account),
      message_type: :outgoing,
      private: true,
      created_at: warning.created_at + 1.second
    )

    result = run_due_close(schedule)

    expect(result[:summary]).to include(closed: 1, cancelled: 0)
    expect(conversation.reload).to be_resolved
  end

  it 'closes normally when an internal activity is created after the warning' do
    schedule = schedule_warning!
    warning = conversation.messages.find(schedule.warning_message_id)
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      message_type: :activity,
      created_at: warning.created_at + 1.second
    )

    result = run_due_close(schedule)

    expect(result[:summary]).to include(closed: 1, cancelled: 0)
    expect(conversation.reload).to be_resolved
  end

  it 'cancels the closure when a human sends a public message after the warning' do
    schedule = schedule_warning!
    warning = conversation.messages.find(schedule.warning_message_id)
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: create(:user, account: account),
      message_type: :outgoing,
      created_at: warning.created_at + 1.second
    )

    result = run_due_close(schedule)

    expect(result[:results].first).to include(status: 'cancelled', reason: 'conversation_changed')
    expect(conversation.reload).to be_pending
  end

  it 'cancels the closure when the conversation is opened during the warning interval' do
    schedule = schedule_warning!
    conversation.update!(status: :open)

    result = run_due_close(schedule)

    expect(result[:results].first).to include(status: 'cancelled', reason: 'conversation_changed')
    expect(conversation.reload).to be_open
  end

  it 'cancels the closure when a human assumes the conversation during the warning interval' do
    schedule = schedule_warning!
    assignee = create(:user, account: account)
    conversation.update!(assignee: assignee)

    result = run_due_close(schedule)

    expect(result[:results].first).to include(status: 'cancelled', reason: 'conversation_changed')
    expect(conversation.reload).to have_attributes(status: 'pending', assignee_id: assignee.id)
  end

  it 'closes without a final customer message when that option is disabled' do
    policy.update!(close_final_message_enabled: false, close_final_message: nil)
    schedule = schedule_warning!

    expect { run_due_close(schedule) }.not_to change(conversation.messages.template, :count)
    expect(conversation.reload).to be_resolved
  end

  private

  def schedule_warning!
    result = Ibsoft::ConversationDistribution::AutomationHandoffExecutor.new(account: account).perform
    expect(result[:summary]).to include(scanned: 1, warnings_sent: 1, closed: 0)

    Ibsoft::ConversationDistribution::AutomationCloseSchedule.find_by!(conversation: conversation)
  end

  def run_due_close(schedule)
    schedule.update!(close_at: 1.minute.ago)
    Ibsoft::ConversationDistribution::AutomationCloseExecutor.new(
      account: account,
      schedule_id: schedule.id
    ).perform
  end

  def create_customer_reply(created_at:)
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      message_type: :incoming,
      created_at: created_at
    )
  end
end

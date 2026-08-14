require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AutomationCloseJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:policy) do
    create(
      :ibsoft_automation_handoff_policy,
      account: account,
      inbox: inbox,
      timeout_action: 'close_conversation',
      target_team: nil,
      close_warning_enabled: true
    )
  end
  let(:schedule) do
    Ibsoft::ConversationDistribution::AutomationCloseSchedule.create!(
      account: account,
      conversation: conversation,
      automation_handoff_policy: policy,
      trigger_message_id: 101,
      warning_message_id: 102,
      expected_policy_updated_at: policy.updated_at,
      close_at: 1.minute.from_now
    )
  end

  it 'uses the scheduled jobs queue' do
    expect(described_class.new.queue_name).to eq('scheduled_jobs')
  end

  it 'executes the persisted schedule in its account scope' do
    result = { summary: { scanned: 1, closed: 1 } }
    executor = instance_double(Ibsoft::ConversationDistribution::AutomationCloseExecutor, perform: result)
    allow(Ibsoft::ConversationDistribution::AutomationCloseExecutor).to receive(:new).with(
      account: account,
      schedule_id: schedule.id
    ).and_return(executor)

    expect(described_class.perform_now(schedule.id)).to eq(result)
  end

  it 'does nothing when the persistent schedule no longer exists' do
    expect(Ibsoft::ConversationDistribution::AutomationCloseExecutor).not_to receive(:new)

    expect(described_class.perform_now(-1)).to eq(status: 'schedule_not_found')
  end
end

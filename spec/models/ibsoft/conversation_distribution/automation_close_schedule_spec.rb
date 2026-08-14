require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AutomationCloseSchedule do
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
  let(:attributes) do
    {
      account: account,
      conversation: conversation,
      automation_handoff_policy: policy,
      trigger_message_id: 101,
      warning_message_id: 102,
      expected_policy_updated_at: policy.updated_at,
      close_at: 1.minute.from_now
    }
  end

  it 'accepts one persistent close schedule per conversation' do
    schedule = described_class.new(attributes)

    expect(schedule).to be_valid
  end

  it 'rejects a second schedule for the same conversation' do
    described_class.create!(attributes)
    duplicate = described_class.new(attributes)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:conversation_id]).to be_present
  end

  it 'rejects resources from another account', :aggregate_failures do
    other_account = create(:account)
    other_conversation = create(:conversation, account: other_account)
    other_policy = create(
      :ibsoft_automation_handoff_policy,
      account: other_account,
      timeout_action: 'close_conversation',
      target_team: nil
    )

    wrong_conversation = described_class.new(attributes.merge(conversation: other_conversation))
    wrong_policy = described_class.new(attributes.merge(automation_handoff_policy: other_policy))

    expect(wrong_conversation).not_to be_valid
    expect(wrong_conversation.errors[:conversation]).to be_present
    expect(wrong_policy).not_to be_valid
    expect(wrong_policy.errors[:automation_handoff_policy]).to be_present
  end

  it 'returns only schedules whose close time has elapsed' do
    due = described_class.create!(attributes.merge(close_at: 1.minute.ago))
    described_class.create!(
      attributes.merge(
        conversation: create(:conversation, account: account, inbox: inbox),
        close_at: 1.minute.from_now
      )
    )

    expect(described_class.due).to contain_exactly(due)
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::AfterHours::WaitStarter do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, team: team, status: :open, assignee: nil) }
  let(:policy) { create(:ibsoft_after_hours_policy, account: account) }
  let(:decision) do
    {
      after_hours_policy_id: policy.id,
      outside_business_hours_cause: 'schedule'
    }
  end

  it 'starts a compact wait and sends the regular outside-hours message' do
    result = described_class.new(conversation: conversation, decision: decision).perform

    wait = Ibsoft::AfterHours::Wait.find_by!(conversation: conversation)
    expect(result).to include(applied: true, status: 'wait_started', wait_id: wait.id)
    expect(wait).to have_attributes(
      account: account,
      team: team,
      after_hours_policy: policy,
      exit_command: policy.exit_command,
      exit_confirmation_message: policy.exit_confirmation_message,
      cause: 'schedule',
      status: 'active'
    )
    expect(wait.entry_message).to have_attributes(content: policy.regular_message, message_type: 'outgoing')
    expect(wait.entry_message.content_attributes).to include(
      'ibsoft_after_hours' => hash_including(
        'event' => 'wait_started',
        'cause' => 'schedule',
        'policy_id' => policy.id
      )
    )
  end

  it 'uses the holiday message and stores only holiday references' do
    calendar = create(:ibsoft_business_calendar, account: account)
    holiday = create(:ibsoft_business_holiday, business_calendar: calendar)
    holiday_decision = decision.merge(
      outside_business_hours_cause: 'holiday',
      business_calendar_id: calendar.id,
      business_holiday_id: holiday.id,
      holiday_name: holiday.name
    )

    described_class.new(conversation: conversation, decision: holiday_decision).perform

    wait = Ibsoft::AfterHours::Wait.find_by!(conversation: conversation)
    expect(wait).to have_attributes(
      cause: 'holiday',
      business_calendar: calendar,
      business_holiday: holiday
    )
    expect(wait.entry_message.content).to eq(policy.holiday_message)
    expect(wait.attributes).not_to have_key('payload')
  end

  it 'is idempotent for the same active wait' do
    first_result = described_class.new(conversation: conversation, decision: decision).perform
    second_result = described_class.new(conversation: conversation.reload, decision: decision).perform

    expect(first_result[:applied]).to be(true)
    expect(second_result).to include(applied: false, status: 'already_active')
    expect(Ibsoft::AfterHours::Wait.where(conversation: conversation).count).to eq(1)
    expect(conversation.messages.where(content: policy.regular_message).count).to eq(1)
  end

  it 'recovers an incomplete active reservation without duplicating the wait' do
    wait = create(
      :ibsoft_after_hours_wait,
      account: account,
      conversation: conversation,
      team: team,
      after_hours_policy: policy,
      entry_message: nil
    )

    result = described_class.new(conversation: conversation.reload, decision: decision).perform

    expect(result).to include(applied: true, status: 'wait_started', wait_id: wait.id)
    expect(wait.reload.entry_message).to have_attributes(content: policy.regular_message)
    expect(Ibsoft::AfterHours::Wait.where(conversation: conversation).count).to eq(1)
    expect(conversation.messages.where(content: policy.regular_message).count).to eq(1)
  end

  it 'does not start a wait for an assigned conversation' do
    conversation.update!(assignee: create(:user, account: account))

    result = described_class.new(conversation: conversation, decision: decision).perform

    expect(result).to include(applied: false, status: 'conversation_not_eligible')
    expect(Ibsoft::AfterHours::Wait.where(conversation: conversation)).to be_empty
  end

  it 'does not start a wait for a resolved conversation' do
    conversation.update!(status: :resolved)

    result = described_class.new(conversation: conversation, decision: decision).perform

    expect(result).to include(applied: false, status: 'conversation_not_eligible')
    expect(Ibsoft::AfterHours::Wait.where(conversation: conversation)).to be_empty
  end

  it 'does not start a wait without a department' do
    conversation.update!(team: nil)

    result = described_class.new(conversation: conversation, decision: decision).perform

    expect(result).to include(applied: false, status: 'conversation_not_eligible')
    expect(Ibsoft::AfterHours::Wait.where(conversation: conversation)).to be_empty
  end

  it 'does not start a wait with a disabled policy' do
    policy.update!(enabled: false)

    result = described_class.new(conversation: conversation, decision: decision).perform

    expect(result).to include(applied: false, status: 'policy_not_available')
    expect(Ibsoft::AfterHours::Wait.where(conversation: conversation)).to be_empty
  end

  it 'cancels the reserved wait when the conversation becomes ineligible before delivery' do
    lock_calls = 0
    allow(conversation).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      lock_calls += 1
      result = method.call(*args, &block)
      conversation.update!(status: :resolved) if lock_calls == 1
      result
    end

    result = described_class.new(conversation: conversation, decision: decision).perform

    wait = Ibsoft::AfterHours::Wait.find_by!(conversation: conversation)
    expect(result).to include(applied: false, status: 'conversation_not_eligible', wait_id: wait.id)
    expect(wait.reload).to have_attributes(status: 'cancelled', finished_at: be_present)
    expect(conversation.messages.where(content: policy.regular_message)).to be_empty
  end

  it 'cancels the wait when the entry message cannot be delivered' do
    builder = instance_double(Messages::MessageBuilder)
    allow(builder).to receive(:perform).and_raise(StandardError, 'delivery failed')
    allow(Messages::MessageBuilder).to receive(:new).and_return(builder)

    expect do
      described_class.new(conversation: conversation, decision: decision).perform
    end.to raise_error(StandardError, 'delivery failed')

    expect(Ibsoft::AfterHours::Wait.find_by!(conversation: conversation)).to have_attributes(
      status: 'cancelled',
      finished_at: be_present,
      entry_message_id: nil
    )
  end

  it 'does not use a policy from another account' do
    foreign_policy = create(:ibsoft_after_hours_policy)

    result = described_class.new(
      conversation: conversation,
      decision: decision.merge(after_hours_policy_id: foreign_policy.id)
    ).perform

    expect(result).to include(applied: false, status: 'policy_not_available')
  end
end

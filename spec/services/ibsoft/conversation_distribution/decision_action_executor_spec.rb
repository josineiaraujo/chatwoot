require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::DecisionActionExecutor do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, team: team, waiting_since: 10.minutes.ago) }

  before do
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
  end

  it 'sends a customer notification only once for the same decision' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: { unavailable: { action: 'notify_customer',
                                                                              message: 'Aguarde um atendente ficar disponivel.' } }
                                                   )
    decision = {
      action: 'notify_customer',
      reason: 'outside_business_hours',
      policy_id: nil,
      fallback_team_id: nil
    }

    first_result = described_class.new(conversation: conversation, decision: decision).perform
    second_result = described_class.new(conversation: conversation.reload, decision: decision).perform

    messages = conversation.reload.messages.outgoing.where(content: 'Aguarde um atendente ficar disponivel.')
    expect(first_result).to include(action_applied: true)
    expect(first_result.dig(:action_result, :status)).to eq('message_sent')
    expect(second_result).to include(action_applied: false)
    expect(second_result.dig(:action_result, :status)).to eq('already_applied')
    expect(messages.count).to eq(1)
    expect(conversation.reload.waiting_since).to be_present
    expect(conversation.first_reply_created_at).to be_nil
  end

  it 'uses the automatic message configured for the decision reason' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: {
                                                       unavailability: {
                                                         no_available_agent: {
                                                           action: 'notify_customer',
                                                           message: 'Todos os atendentes estao ocupados.'
                                                         },
                                                         outside_business_hours: {
                                                           action: 'notify_customer',
                                                           message: 'Estamos fora do horario.'
                                                         }
                                                       }
                                                     }
                                                   )
    decision = {
      action: 'notify_customer',
      reason: 'no_available_agent',
      policy_id: nil,
      fallback_team_id: nil
    }

    result = described_class.new(conversation: conversation, decision: decision).perform

    message = conversation.reload.messages.outgoing.last
    expect(result).to include(action_applied: true)
    expect(result.dig(:action_result, :status)).to eq('message_sent')
    expect(message.content).to eq('Todos os atendentes estao ocupados.')
    expect(message.content_attributes).to include(
      'ibsoft_conversation_distribution' => {
        'action' => 'notify_customer',
        'reason' => 'no_available_agent'
      }
    )
  end

  it 'does not hold the conversation lock while building a customer notification' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: { unavailable: { action: 'notify_customer',
                                                                              message: 'Aguarde um atendente ficar disponivel.' } }
                                                   )
    decision = {
      action: 'notify_customer',
      reason: 'outside_business_hours',
      policy_id: nil,
      fallback_team_id: nil
    }
    lock_depth = 0

    allow(conversation).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      lock_depth += 1
      method.call(*args) { block.call }
    ensure
      lock_depth -= 1
    end
    expect(Messages::MessageBuilder).to receive(:new).and_wrap_original do |method, *args|
      expect(lock_depth).to eq(0)
      method.call(*args)
    end

    described_class.new(conversation: conversation, decision: decision).perform
  end

  it 'moves the conversation to the fallback team and marks it as system transfer' do
    fallback_team = create(:team, account: account)
    decision = {
      action: 'fallback_team',
      reason: 'no_available_agent',
      policy_id: nil,
      fallback_team_id: fallback_team.id
    }

    result = described_class.new(conversation: conversation, decision: decision).perform

    conversation.reload
    expect(result).to include(action_applied: true)
    expect(result.dig(:action_result, :status)).to eq('fallback_team_assigned')
    expect(conversation.team).to eq(fallback_team)
    expect(conversation.assignee).to be_nil
    expect(conversation.additional_attributes).to include(
      'ibsoft_distribution_source' => 'system_team_transfer',
      'ibsoft_distribution_source_reason' => 'fallback_team'
    )
    expect(conversation.additional_attributes['ibsoft_distribution_fallback_team_ids']).to contain_exactly(team.id, fallback_team.id)
  end

  it 'does not repeat the same fallback action' do
    fallback_team = create(:team, account: account)
    decision = {
      action: 'fallback_team',
      reason: 'no_available_agent',
      policy_id: nil,
      fallback_team_id: fallback_team.id
    }

    described_class.new(conversation: conversation, decision: decision).perform
    result = described_class.new(conversation: conversation.reload, decision: decision).perform

    expect(result).to include(action_applied: false)
    expect(result.dig(:action_result, :status)).to eq('already_applied')
    expect(conversation.reload.team).to eq(fallback_team)
  end

  it 'starts an after-hours wait once and sends the policy message once' do
    after_hours_policy = create(:ibsoft_after_hours_policy, account: account)
    decision = {
      action: 'after_hours_policy',
      reason: 'outside_business_hours',
      policy_id: nil,
      after_hours_policy_id: after_hours_policy.id,
      outside_business_hours_cause: 'schedule'
    }

    first_result = described_class.new(conversation: conversation, decision: decision).perform
    second_result = described_class.new(conversation: conversation.reload, decision: decision).perform

    wait = Ibsoft::AfterHours::Wait.find_by!(conversation: conversation)
    messages = conversation.reload.messages.outgoing.where(content: after_hours_policy.regular_message)
    expect(first_result).to include(action_applied: true)
    expect(first_result.dig(:action_result, :status)).to eq('wait_started')
    expect(second_result).to include(action_applied: false)
    expect(second_result.dig(:action_result, :status)).to eq('already_active')
    expect(wait).to be_active
    expect(wait.entry_message).to eq(messages.first)
    expect(messages.count).to eq(1)
  end

  it 'uses the holiday message and stores the calendar references' do
    after_hours_policy = create(:ibsoft_after_hours_policy, account: account)
    calendar = create(:ibsoft_business_calendar, account: account)
    holiday = create(:ibsoft_business_holiday, business_calendar: calendar)
    decision = {
      action: 'after_hours_policy',
      reason: 'outside_business_hours',
      policy_id: nil,
      after_hours_policy_id: after_hours_policy.id,
      outside_business_hours_cause: 'holiday',
      business_calendar_id: calendar.id,
      business_holiday_id: holiday.id
    }

    result = described_class.new(conversation: conversation, decision: decision).perform

    wait = Ibsoft::AfterHours::Wait.find_by!(conversation: conversation)
    expect(result).to include(action_applied: true)
    expect(wait).to have_attributes(
      cause: 'holiday',
      business_calendar_id: calendar.id,
      business_holiday_id: holiday.id
    )
    expect(wait.entry_message.content).to eq(after_hours_policy.holiday_message)
  end

  it 'blocks fallback cycles' do
    fallback_team = create(:team, account: account)
    conversation.update!(
      team: fallback_team,
      additional_attributes: {
        'ibsoft_distribution_fallback_team_ids' => [team.id, fallback_team.id]
      }
    )
    decision = {
      action: 'fallback_team',
      reason: 'no_available_agent',
      policy_id: nil,
      fallback_team_id: team.id
    }

    result = described_class.new(conversation: conversation, decision: decision).perform

    expect(result).to include(action_applied: false)
    expect(result.dig(:action_result, :status)).to eq('fallback_cycle_detected')
    expect(conversation.reload.team).to eq(fallback_team)
  end
end

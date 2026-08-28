require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AgentCapacityEvaluator do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:policy) do
    {
      config: {
        'distribution' => {
          'open_conversation_limit' => 2,
          'capacity_ignore_customer_waiting_enabled' => false,
          'capacity_ignore_customer_waiting_minutes' => 60,
          'capacity_excluded_labels' => []
        }
      }
    }
  end
  let(:evaluator) { described_class.new(account: account, agent: agent, policy: policy) }

  def assigned_conversation(attributes = {})
    create(
      :conversation,
      {
        account: account,
        inbox: inbox,
        assignee: agent,
        status: 'open'
      }.merge(attributes)
    )
  end

  it 'counts only open conversations assigned to the agent in the account' do
    assigned_conversation
    assigned_conversation(status: 'resolved')
    create(:conversation, account: account, inbox: inbox, status: 'open')

    expect(evaluator.current_count).to eq(1)
    expect(evaluator).to be_within_limit
  end

  it 'returns false when the open conversation limit is reached' do
    assigned_conversation
    assigned_conversation

    expect(evaluator.current_count).to eq(2)
    expect(evaluator).not_to be_within_limit
  end

  it 'ignores conversations with configured labels' do
    counted = assigned_conversation
    ignored = assigned_conversation
    ignored.update_labels(['aguardando-cliente'])
    policy[:config]['distribution']['capacity_excluded_labels'] = ['aguardando-cliente']

    expect(evaluator.current_count).to eq(1)
    expect(evaluator.send(:capacity_scope)).to include(counted)
    expect(evaluator.send(:capacity_scope)).not_to include(ignored)
  end

  it 'ignores stale conversations waiting for a customer response' do
    stale_outbound = assigned_conversation
    customer_replied = assigned_conversation
    recent_outbound = assigned_conversation
    policy[:config]['distribution']['open_conversation_limit'] = 3
    policy[:config]['distribution']['capacity_ignore_customer_waiting_enabled'] = true

    create(:message, account: account, inbox: inbox, conversation: stale_outbound, message_type: :outgoing, created_at: 2.hours.ago)
    create(:message, account: account, inbox: inbox, conversation: customer_replied, message_type: :outgoing, created_at: 3.hours.ago)
    create(:message, account: account, inbox: inbox, conversation: customer_replied, message_type: :incoming, created_at: 2.hours.ago)
    create(:message, account: account, inbox: inbox, conversation: recent_outbound, message_type: :outgoing, created_at: 10.minutes.ago)

    expect(evaluator.current_count).to eq(2)
    expect(evaluator.send(:capacity_scope)).not_to include(stale_outbound)
    expect(evaluator.send(:capacity_scope)).to include(customer_replied, recent_outbound)
  end

  it 'remains available immediately below the configured limit' do
    assigned_conversation

    expect(evaluator.current_count).to eq(1)
    expect(evaluator).to be_within_limit
  end

  it 'uses the safe default when the configured limit is invalid' do
    policy[:config]['distribution']['open_conversation_limit'] = 0
    5.times { assigned_conversation }

    expect(evaluator.current_count).to eq(5)
    expect(evaluator).not_to be_within_limit
  end

  it 'ignores a conversation matching any configured excluded label' do
    first_ignored = assigned_conversation
    second_ignored = assigned_conversation
    counted = assigned_conversation
    first_ignored.update_labels(['aguardando-cliente'])
    second_ignored.update_labels(['acompanhamento'])
    policy[:config]['distribution'].merge!(
      'open_conversation_limit' => 2,
      'capacity_excluded_labels' => [' aguardando-cliente ', 'acompanhamento', '']
    )

    expect(evaluator.current_count).to eq(1)
    expect(evaluator.send(:capacity_scope)).to include(counted)
    expect(evaluator.send(:capacity_scope)).not_to include(first_ignored, second_ignored)
  end

  it 'ignores an outbound conversation exactly at the waiting threshold' do
    waiting = assigned_conversation
    policy[:config]['distribution']['capacity_ignore_customer_waiting_enabled'] = true

    travel_to(Time.current.change(usec: 0)) do
      create(
        :message,
        account: account,
        inbox: inbox,
        conversation: waiting,
        message_type: :outgoing,
        created_at: 60.minutes.ago
      )

      expect(evaluator.current_count).to eq(0)
    end
  end

  it 'counts an outbound conversation newer than the waiting threshold' do
    waiting = assigned_conversation
    policy[:config]['distribution']['capacity_ignore_customer_waiting_enabled'] = true
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: waiting,
      message_type: :outgoing,
      created_at: 59.minutes.ago
    )

    expect(evaluator.current_count).to eq(1)
  end

  it 'ignores stale template messages as outbound customer waits' do
    waiting = assigned_conversation
    policy[:config]['distribution']['capacity_ignore_customer_waiting_enabled'] = true
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: waiting,
      message_type: :template,
      created_at: 2.hours.ago
    )

    expect(evaluator.current_count).to eq(0)
  end

  it 'does not treat private or activity messages as the last public customer interaction' do
    private_note = assigned_conversation
    activity = assigned_conversation
    policy[:config]['distribution']['capacity_ignore_customer_waiting_enabled'] = true
    create(:message, account: account, inbox: inbox, conversation: private_note, message_type: :outgoing, created_at: 2.hours.ago)
    create(:message, account: account, inbox: inbox, conversation: private_note, message_type: :outgoing, private: true, created_at: 5.minutes.ago)
    create(:message, account: account, inbox: inbox, conversation: activity, message_type: :outgoing, created_at: 2.hours.ago)
    create(:message, account: account, inbox: inbox, conversation: activity, message_type: :activity, created_at: 5.minutes.ago)

    expect(evaluator.current_count).to eq(0)
  end

  it 'does not count open assignments belonging to another account' do
    other_account = create(:account)
    other_inbox = create(:inbox, account: other_account)
    create(:conversation, account: other_account, inbox: other_inbox, assignee: agent, status: :open)

    expect(evaluator.current_count).to eq(0)
  end
end

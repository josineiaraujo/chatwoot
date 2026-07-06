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
end

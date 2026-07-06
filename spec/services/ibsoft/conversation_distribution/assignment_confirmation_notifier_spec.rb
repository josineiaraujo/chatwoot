require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AssignmentConfirmationNotifier do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:assignee) { create(:user, account: account, name: 'Maria') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, team: team, waiting_since: 10.minutes.ago) }

  before do
    create(
      :ibsoft_distribution_channel_policy,
      account: account,
      inbox: inbox,
      enabled: true,
      config: {
        assignment_confirmation: {
          enabled: true,
          message: 'Seu atendimento foi direcionado para {{agent.name}}.',
          only_before_first_reply: true
        }
      }
    )
  end

  it 'sends a template message with the assigned agent name' do
    result = described_class.new(conversation: conversation, assignee: assignee).perform

    message = conversation.reload.messages.last
    expect(result).to include(applied: true, status: 'message_sent', message_id: message.id)
    expect(message).to be_template
    expect(message.content).to eq('Seu atendimento foi direcionado para Maria.')
    expect(message.private).to be(false)
    expect(message.content_attributes).to include(
      'ibsoft_conversation_distribution' => {
        'action' => 'assignment_confirmation',
        'assignee_id' => assignee.id,
        'assignee_name' => 'Maria'
      }
    )
    expect(conversation.first_reply_created_at).to be_nil
  end

  it 'does not send duplicate confirmations for the same assignment content' do
    first_result = described_class.new(conversation: conversation, assignee: assignee).perform
    second_result = described_class.new(conversation: conversation.reload, assignee: assignee).perform

    expect(first_result).to include(applied: true, status: 'message_sent')
    expect(second_result).to include(applied: false, status: 'already_applied')
    expect(conversation.reload.messages.template.count).to eq(1)
  end

  it 'does not send when the first human reply already exists' do
    conversation.update!(first_reply_created_at: Time.current)

    result = described_class.new(conversation: conversation, assignee: assignee).perform

    expect(result).to include(applied: false, status: 'first_reply_already_exists')
    expect(conversation.reload.messages).to be_blank
  end

  it 'does not send when the policy disables assignment confirmation' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: {
                                                       assignment_confirmation: {
                                                         enabled: false,
                                                         message: 'Seu atendimento foi direcionado para {{agent.name}}.'
                                                       }
                                                     }
                                                   )

    result = described_class.new(conversation: conversation, assignee: assignee).perform

    expect(result).to include(applied: false, status: 'disabled')
    expect(conversation.reload.messages).to be_blank
  end
end

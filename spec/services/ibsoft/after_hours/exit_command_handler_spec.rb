require 'rails_helper'

RSpec.describe Ibsoft::AfterHours::ExitCommandHandler do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:conversation) { create(:conversation, account: account, team: team, status: :open, assignee: nil) }
  let(:policy) { create(:ibsoft_after_hours_policy, account: account, exit_command: 'sair') }

  def incoming_message(content:, created_at: Time.current)
    create(
      :message,
      account: account,
      inbox: conversation.inbox,
      conversation: conversation,
      message_type: :incoming,
      content: content,
      created_at: created_at
    )
  end

  def active_wait(started_at: 1.minute.ago)
    create(
      :ibsoft_after_hours_wait,
      account: account,
      conversation: conversation,
      team: team,
      after_hours_policy: policy,
      started_at: started_at
    )
  end

  it 'resolves the conversation for an exact command ignoring case and outer whitespace' do
    message = incoming_message(content: '  SAIR  ')
    wait = active_wait

    result = described_class.new(message: message).perform

    expect(result).to be(true)
    expect(wait.reload).to have_attributes(status: 'exited', finished_at: be_present)
    expect(wait.exit_message).to have_attributes(
      content: policy.exit_confirmation_message,
      message_type: 'outgoing'
    )
    expect(conversation.reload).to be_resolved
    expect(conversation.assignee).to be_nil
  end

  it 'does not consume a different customer message' do
    message = incoming_message(content: 'quero atendimento')
    wait = active_wait

    result = described_class.new(message: message).perform

    expect(result).to be(false)
    expect(wait.reload).to be_active
    expect(conversation.reload).to be_open
  end

  it 'uses the command and confirmation captured when the wait began' do
    original_confirmation = policy.exit_confirmation_message
    message = incoming_message(content: 'sair')
    wait = active_wait(started_at: 1.minute.ago)
    policy.update!(
      exit_command: 'cancelar',
      exit_confirmation_message: 'Nova confirmacao para esperas futuras.'
    )

    result = described_class.new(message: message).perform

    expect(result).to be(true)
    expect(wait.reload.exit_message.content).to eq(original_confirmation)
    expect(conversation.reload).to be_resolved
  end

  it 'does not consume a command sent before the wait began' do
    message = incoming_message(content: 'sair', created_at: 2.minutes.ago)
    wait = active_wait(started_at: 1.minute.ago)

    result = described_class.new(message: message).perform

    expect(result).to be(false)
    expect(wait.reload).to be_active
  end

  it 'does not resolve a conversation that was assigned while waiting' do
    message = incoming_message(content: 'sair')
    wait = active_wait
    conversation.update!(assignee: create(:user, account: account))

    result = described_class.new(message: message).perform

    expect(result).to be(false)
    expect(wait.reload).to have_attributes(status: 'cancelled', finished_at: be_present)
    expect(conversation.reload).to be_open
  end

  it 'ignores private and outgoing messages' do
    wait = active_wait
    private_message = create(
      :message,
      account: account,
      inbox: conversation.inbox,
      conversation: conversation,
      message_type: :incoming,
      content: 'sair',
      private: true
    )
    outgoing_message = create(
      :message,
      account: account,
      inbox: conversation.inbox,
      conversation: conversation,
      message_type: :outgoing,
      content: 'sair'
    )

    expect(described_class.new(message: private_message).perform).to be(false)
    expect(described_class.new(message: outgoing_message).perform).to be(false)
    expect(wait.reload).to be_active
  end
end

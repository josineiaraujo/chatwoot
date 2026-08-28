require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AutomationCustomerMessageNotifier do
  let(:account) { create(:account, locale: 'pt_BR') }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending) }
  let(:policy) do
    create(
      :ibsoft_automation_handoff_policy,
      account: account,
      inbox: inbox,
      timeout_action: 'close_conversation',
      target_team: nil,
      close_warning_enabled: true,
      close_warning_delay_minutes: 2,
      close_final_message_enabled: true
    )
  end

  it 'sends the localized default warning with automation metadata' do
    result = described_class.new(conversation: conversation, policy: policy, phase: :close_warning).perform

    message = conversation.messages.template.last
    expect(result).to include(applied: true, status: 'message_sent', message_id: message.id)
    expect(message).to have_attributes(
      content: 'Você ainda está aí? Seu atendimento será encerrado em 2 minutos.',
      private: false
    )
    expect(message.content_attributes['ibsoft_conversation_distribution']).to include(
      'action' => 'close_warning',
      'reason' => 'automation_stalled'
    )
  end

  it 'uses the configured warning instead of the default text' do
    policy.update!(close_warning_message: 'Posso ajudar em algo mais?')

    described_class.new(conversation: conversation, policy: policy, phase: :close_warning).perform

    expect(conversation.messages.template.last.content).to eq('Posso ajudar em algo mais?')
  end

  it 'sends the localized default final message when enabled' do
    result = described_class.new(conversation: conversation, policy: policy, phase: :close_final).perform

    message = conversation.messages.template.last
    expect(result).to include(applied: true, status: 'message_sent', message_id: message.id)
    expect(message.content).to eq(
      'Atendimento encerrado por falta de resposta. Quando precisar, envie uma nova mensagem.'
    )
    expect(message.content_attributes['ibsoft_conversation_distribution']['action']).to eq('close_conversation')
  end

  it 'does not create a customer message when the selected phase is disabled' do
    policy.update!(close_warning_enabled: false)

    expect do
      result = described_class.new(conversation: conversation, policy: policy, phase: :close_warning).perform
      expect(result).to include(applied: false, status: 'disabled')
    end.not_to change(conversation.messages, :count)
  end

  it 'does not create a forwarding message when the enabled content is blank' do
    policy.update!(
      timeout_action: 'forward_to_team',
      target_team: create(:team, account: account),
      customer_message_enabled: true,
      customer_message: nil
    )

    expect do
      result = described_class.new(conversation: conversation, policy: policy, phase: :forward).perform
      expect(result).to include(applied: false, status: 'blank_message')
    end.not_to change(conversation.messages, :count)
  end

  it 'returns a controlled error for an unsupported phase' do
    result = described_class.new(conversation: conversation, policy: policy, phase: :unsupported).perform

    expect(result).to include(applied: false, status: 'error', error: 'ArgumentError')
  end

  it 'contains builder failures without interrupting the automation flow' do
    builder = instance_double(Messages::MessageBuilder)
    allow(Messages::MessageBuilder).to receive(:new).and_return(builder)
    allow(builder).to receive(:perform).and_raise(StandardError, 'channel unavailable')

    result = described_class.new(conversation: conversation, policy: policy, phase: :close_warning).perform

    expect(result).to include(applied: false, status: 'error', error: 'StandardError')
  end
end

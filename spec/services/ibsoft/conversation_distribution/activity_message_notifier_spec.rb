require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::ActivityMessageNotifier do
  let(:account) { create(:account, locale: 'pt_BR') }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:previous_assignee) { create(:user, account: account, name: 'Agente Anterior') }
  let(:assignee) { create(:user, account: account, name: 'Agente Novo') }

  it 'creates an internal activity message for automatic assignment' do
    result = nil

    perform_enqueued_jobs(only: Conversations::ActivityMessageJob) do
      result = described_class.new(
        conversation: conversation,
        action: :assignment_completed,
        assignee: assignee
      ).perform
    end

    expect(result).to include(applied: true, status: 'enqueued')
    expect(conversation.messages.activity.last.content).to eq(
      'Atendimento atribuído automaticamente para Agente Novo pela distribuição automática.'
    )
  end

  it 'creates an internal activity message for redistribution' do
    perform_enqueued_jobs(only: Conversations::ActivityMessageJob) do
      described_class.new(
        conversation: conversation,
        action: :redistribution_completed,
        previous_assignee: previous_assignee,
        assignee: assignee
      ).perform
    end

    expect(conversation.messages.activity.last.content).to eq(
      'Atendimento redistribuído automaticamente de Agente Anterior para Agente Novo ' \
      'pela redistribuição automática por exceder o tempo de espera.'
    )
  end
end

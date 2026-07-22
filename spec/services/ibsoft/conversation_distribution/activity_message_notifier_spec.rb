require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::ActivityMessageNotifier do
  let(:account) { create(:account, locale: 'pt_BR') }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:previous_assignee) { create(:user, account: account, name: 'Agente Anterior') }
  let(:assignee) { create(:user, account: account, name: 'Agente Novo') }
  let(:target_team) { create(:team, account: account, name: 'Suporte') }

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

  it 'creates an internal activity message for automation handoff' do
    perform_enqueued_jobs(only: Conversations::ActivityMessageJob) do
      described_class.new(
        conversation: conversation,
        action: :automation_handoff_completed,
        target_team: target_team
      ).perform
    end

    expect(conversation.messages.activity.last.content).to eq(
      "Atendimento encaminhado automaticamente da automação para #{target_team.reload.name} por inatividade."
    )
  end

  it 'creates an internal activity message when an agent returns a conversation to the queue' do
    perform_enqueued_jobs(only: Conversations::ActivityMessageJob) do
      described_class.new(
        conversation: conversation,
        action: :queue_returned,
        assignee: previous_assignee,
        target_team: target_team
      ).perform
    end

    expect(conversation.messages.activity.last.content).to eq(
      "Atendimento devolvido por Agente Anterior à fila do departamento #{target_team.reload.name}."
    )
  end

  it 'creates an internal activity message when an agent transfers a conversation to a queue' do
    perform_enqueued_jobs(only: Conversations::ActivityMessageJob) do
      described_class.new(
        conversation: conversation,
        action: :queue_transferred,
        assignee: assignee,
        target_team: target_team
      ).perform
    end

    expect(conversation.messages.activity.last.content).to eq(
      "Atendimento transferido por Agente Novo para a fila do departamento #{target_team.reload.name}."
    )
  end
end

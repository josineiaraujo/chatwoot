# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ibsoft::MessageSignature::MessageBuilderExtension do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, name: 'Maria Suporte') }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  before do
    account.update!(
      settings: {
        Ibsoft::MessageSignature::Configuration::SETTINGS_KEY => {
          'enabled' => true,
          'inbox_ids' => [inbox.id]
        }
      }
    )
  end

  def build_message(params)
    Messages::MessageBuilder.new(user, conversation, params).perform
  end

  it 'signs a public message sent by a human agent through a selected channel' do
    message = build_message(ActionController::Parameters.new(content: 'Como posso ajudar?'))

    expect(message.content).to eq("**Maria Suporte**\n\nComo posso ajudar?")
    expect(message.sender).to eq(user)
  end

  it 'does not sign a private note' do
    message = build_message(ActionController::Parameters.new(content: 'Nota interna', private: true))

    expect(message.content).to eq('Nota interna')
  end

  it 'does not sign when the account configuration is disabled' do
    account.update!(
      settings: {
        Ibsoft::MessageSignature::Configuration::SETTINGS_KEY => {
          'enabled' => false,
          'inbox_ids' => [inbox.id]
        }
      }
    )

    message = build_message(ActionController::Parameters.new(content: 'Olá!'))

    expect(message.content).to eq('Olá!')
  end

  it 'does not sign a Meta template message' do
    message = build_message(
      ActionController::Parameters.new(content: 'Template', template_params: { name: 'hello_world' })
    )

    expect(message.content).to eq('Template')
  end

  it 'does not sign messages created by backend automations using hash parameters' do
    message = build_message({ content: 'Mensagem automática' })

    expect(message.content).to eq('Mensagem automática')
  end

  it 'does not sign a message attributed to an agent bot' do
    agent_bot = create(:agent_bot, account: account)

    message = build_message(
      ActionController::Parameters.new(
        content: 'Mensagem do robô',
        sender_type: 'AgentBot',
        sender_id: agent_bot.id
      )
    )

    expect(message.content).to eq('Mensagem do robô')
    expect(message.sender).to eq(agent_bot)
  end

  it 'does not sign a message created by an automation rule' do
    message = build_message(
      ActionController::Parameters.new(
        content: 'Mensagem automática',
        content_attributes: { automation_rule_id: 7 }
      )
    )

    expect(message.content).to eq('Mensagem automática')
  end

  it 'does not sign a message sent through the external API' do
    message = Ibsoft::MessageSignature::RequestContext.set(external_api_request: true) do
      build_message(ActionController::Parameters.new(content: 'Mensagem da API'))
    end

    expect(message.content).to eq('Mensagem da API')
  end

  it 'does not sign an incoming API message' do
    api_channel = create(:channel_api, account: account)
    api_inbox = api_channel.inbox
    api_conversation = create(:conversation, account: account, inbox: api_inbox)
    account.update!(
      settings: {
        Ibsoft::MessageSignature::Configuration::SETTINGS_KEY => {
          'enabled' => true,
          'inbox_ids' => [api_inbox.id]
        }
      }
    )

    message = Messages::MessageBuilder.new(
      user,
      api_conversation,
      ActionController::Parameters.new(content: 'Mensagem do cliente', message_type: 'incoming')
    ).perform

    expect(message.content).to eq('Mensagem do cliente')
    expect(message.sender).to eq(api_conversation.contact)
  end

  it 'does not sign messages in a channel that was not selected' do
    other_inbox = create(:inbox, account: account)
    other_conversation = create(:conversation, account: account, inbox: other_inbox)

    message = Messages::MessageBuilder.new(
      user,
      other_conversation,
      ActionController::Parameters.new(content: 'Olá!')
    ).perform

    expect(message.content).to eq('Olá!')
  end

  it 'replaces a stale native footer with the private header signature' do
    user.update!(message_signature: 'Obrigado, Maria')

    message = build_message(
      ActionController::Parameters.new(content: "Olá!\n\n--\n\nObrigado, Maria")
    )

    expect(message.content).to eq("**Maria Suporte**\n\nOlá!")
  end

  it 'does not duplicate the private signature when a pending draft already contains it' do
    content = "**Maria Suporte**\n\nOlá!"

    expect(build_message(ActionController::Parameters.new(content: content)).content).to eq(content)
  end
end

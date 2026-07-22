# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ibsoft message signature API source detection', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent, name: 'Maria Suporte') }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:url) do
    api_v1_account_conversation_messages_url(
      account_id: account.id,
      conversation_id: conversation.display_id
    )
  end

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    account.update!(
      settings: {
        Ibsoft::MessageSignature::Configuration::SETTINGS_KEY => {
          'enabled' => true,
          'inbox_ids' => [inbox.id]
        }
      }
    )
  end

  it 'preserves content sent with the public API token' do
    post url,
         params: { content: 'Mensagem da API' },
         headers: { api_access_token: agent.access_token.token },
         as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.messages.last.content).to eq('Mensagem da API')
  end

  it 'continues signing messages sent from the dashboard session' do
    post url,
         params: { content: 'Mensagem do painel' },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.messages.last.content).to eq("**Maria Suporte**\n\nMensagem do painel")
  end
end

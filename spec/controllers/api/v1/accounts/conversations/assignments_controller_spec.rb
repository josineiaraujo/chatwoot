require 'rails_helper'

RSpec.describe 'Conversation Assignment API', type: :request do
  let(:account) { create(:account) }

  describe 'POST /api/v1/accounts/{account.id}/conversations/<id>/assignments' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post api_v1_account_conversation_assignments_url(account_id: account.id, conversation_id: conversation.display_id)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated bot with out access to the inbox' do
      let(:agent_bot) { create(:agent_bot) }
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, inbox: conversation.inbox, user: agent)
      end

      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/assignments",
             headers: { api_access_token: agent_bot.access_token.token },
             params: {
               assignee_id: agent.id
             },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user with access to the inbox' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:agent_bot) { create(:agent_bot, account: account) }
      let(:team) { create(:team, account: account) }

      before do
        create(:inbox_member, inbox: conversation.inbox, user: agent)
      end

      it 'assigns a user to the conversation' do
        params = { assignee_id: agent.id }

        post api_v1_account_conversation_assignments_url(account_id: account.id, conversation_id: conversation.display_id),
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.assignee).to eq(agent)
      end

      it 'assigns an agent bot to the conversation' do
        params = { assignee_id: agent_bot.id, assignee_type: 'AgentBot' }

        expect(Conversations::AssignmentService).to receive(:new)
          .with(hash_including(conversation: conversation, assignee_id: agent_bot.id, assignee_type: 'AgentBot'))
          .and_call_original

        post api_v1_account_conversation_assignments_url(account_id: account.id, conversation_id: conversation.display_id),
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['name']).to eq(agent_bot.name)
        conversation.reload
        expect(conversation.assignee_agent_bot).to eq(agent_bot)
        expect(conversation.assignee).to be_nil
      end

      it 'assigns a team to the conversation' do
        team_member = create(:user, account: account, role: :agent, auto_offline: false)
        create(:inbox_member, inbox: conversation.inbox, user: team_member)
        create(:team_member, team: team, user: team_member)
        params = { team_id: team.id }

        post api_v1_account_conversation_assignments_url(account_id: account.id, conversation_id: conversation.display_id),
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.team).to eq(team)
        # assignee will be from team
        expect(conversation.reload.assignee).to eq(team_member)
        expect(conversation.reload.additional_attributes['ibsoft_distribution_source']).to eq('manual_team_transfer')
      end

      it 'clears the complete AI owner when a manual team transfer enters private distribution' do
        manual_team = create(:team, account: account, allow_auto_assign: false)
        create(:ibsoft_distribution_channel_policy, account: account, inbox: conversation.inbox, enabled: true)
        allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive_messages(
          job_enabled?: true,
          real_assignment_enabled?: true
        )
        owner_attribute = conversation.respond_to?(:ai_assignee=) ? :ai_assignee : :assignee_agent_bot
        conversation.update!({ :status => :pending, :assignee => nil, owner_attribute => agent_bot })

        post api_v1_account_conversation_assignments_url(account_id: account.id, conversation_id: conversation.display_id),
             params: { team_id: manual_team.id },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        conversation.reload
        expect(conversation).to have_attributes(
          team: manual_team,
          assignee: nil,
          assignee_agent_bot: nil
        )
        expect(conversation.ai_assignee).to be_nil if conversation.respond_to?(:ai_assignee)
        expect(conversation.ai_assignee_type).to be_nil if conversation.has_attribute?(:ai_assignee_type)
        expect(conversation.additional_attributes['ibsoft_distribution_source']).to eq('manual_team_transfer')
      end
    end

    context 'when it is an authenticated bot with access to the inbox' do
      let(:agent_bot) { create(:agent_bot, account: account) }
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:team) { create(:team, account: account) }

      before do
        create(:agent_bot_inbox, inbox: conversation.inbox, agent_bot: agent_bot)
      end

      it 'assignment of an agent in the conversation by bot agent' do
        create(:inbox_member, user: agent, inbox: conversation.inbox)

        conversation.update!(assignee_id: nil)
        expect(conversation.reload.assignee).to be_nil

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/assignments",
             headers: { api_access_token: agent_bot.access_token.token },
             params: {
               assignee_id: agent.id
             },
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.assignee).to eq(agent)
      end

      it 'assignment of an team in the conversation by bot agent' do
        create(:inbox_member, user: agent, inbox: conversation.inbox)

        conversation.update!(team_id: nil)
        expect(conversation.reload.team).to be_nil

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/assignments",
             headers: { api_access_token: agent_bot.access_token.token },
             params: {
               team_id: team.id
             },
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.team).to eq(team)
        expect(conversation.reload.additional_attributes['ibsoft_distribution_source']).to eq('system_team_transfer')
      end
    end

    context 'when conversation already has an assignee' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, inbox: conversation.inbox, user: agent)
        conversation.update!(assignee: agent)
      end

      it 'unassigns the assignee from the conversation' do
        params = { assignee_id: nil }
        post api_v1_account_conversation_assignments_url(account_id: account.id, conversation_id: conversation.display_id),
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.assignee).to be_nil
        expect(Conversations::ActivityMessageJob)
          .to(have_been_enqueued.at_least(:once)
        .with(conversation, { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
                              content: "Conversation unassigned by #{agent.name}" }))
      end
    end

    context 'when conversation already has a team' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:team) { create(:team, account: account) }

      before do
        conversation.update!(team: team)
        create(:inbox_member, inbox: conversation.inbox, user: agent)
      end

      it 'unassigns the team from the conversation' do
        params = { team_id: 0 }
        post api_v1_account_conversation_assignments_url(account_id: account.id, conversation_id: conversation.display_id),
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.team).to be_nil
      end
    end
  end
end

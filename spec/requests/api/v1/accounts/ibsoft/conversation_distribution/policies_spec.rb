require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::ConversationDistribution::Policies', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:supervisor_user) { create(:user, account: account) }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:agent_headers) { { api_access_token: agent.access_token.token } }
  let(:supervisor_headers) { { api_access_token: supervisor_user.access_token.token } }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/conversation_distribution" }

  def grant_supervisor_permission(user)
    role = create(
      :ibsoft_access_control_role,
      account: account,
      permissions: [Ibsoft::ConversationDistribution::SupervisorPermission::PERMISSION]
    )
    create(:ibsoft_access_control_role_assignment, account: account, role: role, user: user)
  end

  describe 'distribution policies catalog' do
    it 'allows administrators to create, list and update named policies' do
      post "#{base_url}/policies",
           params: {
             name: 'Comercial padrao',
             enabled: true,
             config: { distribution: { max_assignments_per_round: 2 } }
           },
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:success)
      policy_id = response.parsed_body['id']
      expect(response.parsed_body).to include(
        'name' => 'Comercial padrao',
        'enabled' => true,
        'policy_type' => 'named'
      )

      get "#{base_url}/policies", headers: admin_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['policies'].pluck('id')).to include(policy_id)

      patch "#{base_url}/policies/#{policy_id}",
            params: { name: 'Comercial atualizado', enabled: false },
            headers: admin_headers,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('name' => 'Comercial atualizado', 'enabled' => false)
    end

    it 'blocks agents from managing named policies' do
      get "#{base_url}/policies", headers: agent_headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'persists separate actions for no available agent and outside business hours' do
      fallback_team = create(:team, account: account)

      post "#{base_url}/policies",
           params: {
             name: 'Suporte com fallback',
             enabled: true,
             config: {
               unavailability: {
                 no_available_agent: {
                   action: 'fallback_team',
                   fallback_team_id: fallback_team.id
                 },
                 outside_business_hours: {
                   action: 'notify_customer',
                   message: 'Estamos fora do horario.'
                 }
               }
             }
           },
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('config', 'unavailability', 'no_available_agent')).to include(
        'action' => 'fallback_team',
        'fallback_team_id' => fallback_team.id
      )
      expect(response.parsed_body.dig('config', 'unavailability', 'outside_business_hours')).to include(
        'action' => 'notify_customer',
        'message' => 'Estamos fora do horario.'
      )
      expect(response.parsed_body.dig('config', 'unavailable', 'action')).to eq('wait')
    end

    it 'persists assignment confirmation settings' do
      post "#{base_url}/policies",
           params: {
             name: 'Confirmacao de atendimento',
             enabled: true,
             config: {
               assignment_confirmation: {
                 enabled: true,
                 message: 'Seu atendimento foi direcionado para {{agent.name}}.',
                 only_before_first_reply: true
               }
             }
           },
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('config', 'assignment_confirmation')).to include(
        'enabled' => true,
        'message' => 'Seu atendimento foi direcionado para {{agent.name}}.',
        'only_before_first_reply' => true
      )
    end
  end

  describe 'PATCH /inbox_policies/:inbox_id' do
    it 'does not store inline channel configuration without a named policy' do
      patch "#{base_url}/inbox_policies/#{inbox.id}",
            params: {
              enabled: true,
              config: {
                unavailable: { action: 'notify_customer', message: 'Aguarde um momento.' }
              }
            },
            headers: admin_headers,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        'enabled' => false,
        'inbox_id' => inbox.id,
        'policy_type' => 'channel'
      )
      expect(response.parsed_body.dig('native_assignment', 'inbox_auto_assignment_enabled')).to eq(
        inbox.reload.enable_auto_assignment
      )
      expect(response.parsed_body['distribution_policy_id']).to be_nil
      expect(response.parsed_body.dig('config', 'unavailable', 'action')).to eq('wait')
    end

    it 'links a named policy to the channel' do
      named_policy = create(:ibsoft_distribution_policy, account: account, name: 'Canal padrao', enabled: true)

      patch "#{base_url}/inbox_policies/#{inbox.id}",
            params: { distribution_policy_id: named_policy.id },
            headers: admin_headers,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        'distribution_policy_id' => named_policy.id,
        'distribution_policy_name' => 'Canal padrao',
        'enabled' => true
      )
    end

    it 'blocks agents from changing policies' do
      patch "#{base_url}/inbox_policies/#{inbox.id}",
            params: { enabled: true },
            headers: agent_headers,
            as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH /team_policies/:team_id' do
    it 'allows administrators to save a disabled team override without inline configuration' do
      patch "#{base_url}/team_policies/#{team.id}",
            params: {
              enabled: true,
              override_channel_policy: true,
              config: {
                business_hours: {
                  mode: 'custom',
                  timezone: 'America/Sao_Paulo',
                  schedule: [
                    {
                      day_of_week: 1,
                      closed_all_day: false,
                      open_all_day: false,
                      open_hour: 9,
                      open_minutes: 0,
                      close_hour: 17,
                      close_minutes: 0
                    }
                  ]
                },
                supervisor_alert: { enabled: true, threshold_minutes: 20 }
              }
            },
            headers: admin_headers,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        'enabled' => false,
        'team_id' => team.id,
        'override_channel_policy' => true,
        'policy_type' => 'team'
      )
      expect(response.parsed_body.dig('native_assignment', 'team_auto_assignment_enabled')).to eq(
        team.reload.allow_auto_assign
      )
      expect(response.parsed_body['distribution_policy_id']).to be_nil
      expect(response.parsed_body.dig('config', 'business_hours', 'mode')).to eq('inherit_channel')
    end

    it 'links a named policy to the team override' do
      named_policy = create(:ibsoft_distribution_policy, account: account, name: 'Time comercial', enabled: true)

      patch "#{base_url}/team_policies/#{team.id}",
            params: {
              override_channel_policy: true,
              distribution_policy_id: named_policy.id
            },
            headers: admin_headers,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        'distribution_policy_id' => named_policy.id,
        'distribution_policy_name' => 'Time comercial',
        'override_channel_policy' => true,
        'enabled' => true
      )
    end
  end

  describe 'GET /effective_policy' do
    it 'returns the effective policy for inbox and team' do
      create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
      create(:ibsoft_distribution_team_policy, account: account, team: team, enabled: false, override_channel_policy: true)

      get "#{base_url}/effective_policy",
          params: { inbox_id: inbox.id, team_id: team.id },
          headers: admin_headers,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        'enabled' => false,
        'source' => 'team',
        'policy_type' => 'team'
      )
    end
  end

  describe 'GET /dry_runs' do
    it 'returns a read-only preview of eligible conversations' do
      create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
      conversation = create(:conversation, account: account, inbox: inbox, team: team)
      conversation.update!(waiting_since: 10.minutes.ago)
      create(
        :reporting_event,
        account: account,
        inbox: inbox,
        conversation: conversation,
        name: 'conversation_bot_handoff'
      )

      get "#{base_url}/dry_runs",
          params: { inbox_id: inbox.id, team_id: team.id },
          headers: admin_headers,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('summary', 'eligible')).to eq(1)
      expect(response.parsed_body.dig('candidates', 0)).to include(
        'conversation_id' => conversation.id,
        'source' => 'bot_handoff',
        'eligible' => true
      )
    end

    it 'blocks agents from reading dry-run previews' do
      get "#{base_url}/dry_runs",
          headers: agent_headers,
          as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /supervisor_alerts' do
    it 'returns supervisor alerts for administrators' do
      create(
        :ibsoft_distribution_channel_policy,
        account: account,
        inbox: inbox,
        enabled: true,
        config: { supervisor_alert: { enabled: true, threshold_minutes: 5 } }
      )
      conversation = create(:conversation, account: account, inbox: inbox, team: team)
      conversation.update!(waiting_since: 10.minutes.ago)

      get "#{base_url}/supervisor_alerts",
          params: { inbox_id: inbox.id, team_id: team.id },
          headers: admin_headers,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('summary', 'alerts')).to eq(1)
      expect(response.parsed_body.dig('alerts', 0)).to include(
        'conversation_id' => conversation.id,
        'display_id' => conversation.display_id,
        'reason' => 'unassigned_waiting'
      )
    end

    it 'blocks agents from reading supervisor alerts' do
      get "#{base_url}/supervisor_alerts",
          headers: agent_headers,
          as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'allows users with an Ibsoft access profile to read supervisor alerts' do
      grant_supervisor_permission(supervisor_user)
      create(
        :ibsoft_distribution_channel_policy,
        account: account,
        inbox: inbox,
        enabled: true,
        config: { supervisor_alert: { enabled: true, threshold_minutes: 5 } }
      )
      conversation = create(:conversation, account: account, inbox: inbox, team: team)
      conversation.update!(waiting_since: 10.minutes.ago)

      get "#{base_url}/supervisor_alerts",
          headers: supervisor_headers,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('summary', 'alerts')).to eq(1)
    end
  end

  describe 'GET /agent_assignments' do
    it 'returns waiting conversations available to the current agent' do
      create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
      create(:inbox_member, inbox: inbox, user: agent)
      create(:team_member, team: team, user: agent)
      account.account_users.find_by!(user: agent).update!(availability: :online)
      conversation = create(:conversation, account: account, inbox: inbox, team: team)
      conversation.update!(waiting_since: 10.minutes.ago)
      Ibsoft::ConversationDistribution::SourceMarker.new(
        conversation: conversation,
        source: 'manual_team_transfer'
      ).perform
      allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')

      get "#{base_url}/agent_assignments",
          headers: agent_headers,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('summary', 'available')).to eq(1)
      expect(response.parsed_body.dig('candidates', 0)).to include(
        'conversation_id' => conversation.id,
        'required' => true
      )
    end
  end

  describe 'GET /event_logs' do
    it 'returns audit events for administrators' do
      conversation = create(:conversation, account: account, inbox: inbox, team: team)
      conversation.contact.update!(name: 'Jane Cliente')
      create(
        :ibsoft_distribution_event_log,
        account: account,
        inbox: inbox,
        team: team,
        conversation: conversation,
        event_type: 'assignment_completed',
        reason: 'eligible_for_assignment',
        metadata: { source: 'manual_team_transfer' }
      )

      get "#{base_url}/event_logs",
          params: { event_type: 'assignment_completed', inbox_id: inbox.id },
          headers: admin_headers,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('summary', 'total')).to eq(1)
      expect(response.parsed_body.dig('events', 0)).to include(
        'event_type' => 'assignment_completed',
        'reason' => 'eligible_for_assignment'
      )
      expect(response.parsed_body.dig('events', 0, 'conversation')).to include(
        'id' => conversation.id,
        'display_id' => conversation.display_id
      )
      expect(response.parsed_body.dig('events', 0, 'conversation', 'contact')).to include(
        'id' => conversation.contact.id,
        'name' => 'Jane Cliente',
        'email' => conversation.contact.email
      )
    end

    it 'blocks agents from reading audit events' do
      get "#{base_url}/event_logs",
          headers: agent_headers,
          as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'allows users with an Ibsoft access profile to read audit events' do
      grant_supervisor_permission(supervisor_user)
      create(:ibsoft_distribution_event_log, account: account, inbox: inbox, team: team)

      get "#{base_url}/event_logs",
          headers: supervisor_headers,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('summary', 'total')).to eq(1)
    end
  end

  describe 'POST /agent_assignments/claim' do
    it 'allows an agent to claim an eligible waiting conversation' do
      create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
      create(:inbox_member, inbox: inbox, user: agent)
      create(:team_member, team: team, user: agent)
      account.account_users.find_by!(user: agent).update!(availability: :online)
      conversation = create(:conversation, account: account, inbox: inbox, team: team)
      conversation.update!(waiting_since: 10.minutes.ago)
      Ibsoft::ConversationDistribution::SourceMarker.new(
        conversation: conversation,
        source: 'manual_team_transfer'
      ).perform
      allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

      post "#{base_url}/agent_assignments/claim",
           params: { conversation_ids: [conversation.id] },
           headers: agent_headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('summary', 'assigned')).to eq(1)
      expect(conversation.reload.assignee).to eq(agent)
    end
  end

  describe 'POST /executions' do
    it 'runs the executor in safe mode and keeps conversations unassigned' do
      create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
      conversation = create(:conversation, account: account, inbox: inbox, team: team, waiting_since: 10.minutes.ago)
      Ibsoft::ConversationDistribution::SourceMarker.new(
        conversation: conversation,
        source: 'manual_team_transfer'
      ).perform
      allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(false)

      post "#{base_url}/executions",
           params: { inbox_id: inbox.id, team_id: team.id },
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('real_assignment_enabled' => false)
      expect(response.parsed_body.dig('summary', 'skipped')).to eq(1)
      expect(conversation.reload.assignee).to be_nil
    end

    it 'assigns eligible conversations through Ibsoft execution when Assignment V2 is disabled' do
      account.disable_features!('assignment_v2')
      create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
      create(:inbox_member, inbox: inbox, user: agent)
      create(:team_member, team: team, user: agent)
      conversation = create(:conversation, account: account, inbox: inbox, team: team, waiting_since: 10.minutes.ago)
      Ibsoft::ConversationDistribution::SourceMarker.new(
        conversation: conversation,
        source: 'manual_team_transfer'
      ).perform
      allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(agent.id.to_s => 'online')
      allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(true)

      post "#{base_url}/executions",
           params: { inbox_id: inbox.id, team_id: team.id },
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(inbox.reload.auto_assignment_v2_enabled?).to be(false)
      expect(response.parsed_body).to include('real_assignment_enabled' => true)
      expect(response.parsed_body.dig('summary', 'assigned')).to eq(1)
      expect(conversation.reload.assignee).to eq(agent)
    end

    it 'blocks agents from running executions' do
      post "#{base_url}/executions",
           headers: agent_headers,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end

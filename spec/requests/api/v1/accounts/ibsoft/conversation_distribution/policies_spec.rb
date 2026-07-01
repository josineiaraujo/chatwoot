require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::ConversationDistribution::Policies', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:other_team) { create(:team, account: account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:agent_headers) { { api_access_token: agent.access_token.token } }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/conversation_distribution" }

  describe 'PATCH /inbox_policies/:inbox_id' do
    it 'allows administrators to save channel distribution policy' do
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
        'enabled' => true,
        'inbox_id' => inbox.id,
        'policy_type' => 'channel'
      )
      expect(response.parsed_body.dig('config', 'unavailable', 'action')).to eq('notify_customer')
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
    it 'allows administrators to save team overrides' do
      patch "#{base_url}/team_policies/#{team.id}",
            params: {
              enabled: true,
              override_channel_policy: true,
              config: {
                business_hours: { mode: 'custom', timezone: 'America/Sao_Paulo', schedule: [] },
                supervisor_alert: { enabled: true, threshold_minutes: 20 }
              }
            },
            headers: admin_headers,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        'enabled' => true,
        'team_id' => team.id,
        'override_channel_policy' => true,
        'policy_type' => 'team'
      )
      expect(response.parsed_body.dig('config', 'business_hours', 'mode')).to eq('custom')
    end
  end

  describe 'POST /team_policies/copy' do
    it 'copies rules from another team' do
      create(
        :ibsoft_distribution_team_policy,
        account: account,
        team: team,
        enabled: true,
        override_channel_policy: true,
        config: { unavailable: { action: 'fallback_team', fallback_team_id: other_team.id } }
      )

      post "#{base_url}/team_policies/copy",
           params: { source_team_id: team.id, target_team_id: other_team.id },
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        'enabled' => true,
        'team_id' => other_team.id,
        'override_channel_policy' => true
      )
      expect(response.parsed_body.dig('config', 'unavailable', 'fallback_team_id')).to eq(other_team.id)
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
      conversation = create(:conversation, account: account, inbox: inbox, team: team, waiting_since: 10.minutes.ago)
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

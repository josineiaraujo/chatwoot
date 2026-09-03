require 'rails_helper'

RSpec.describe 'Ibsoft manual team transfer distribution', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let(:source_team) { create(:team, account: account, allow_auto_assign: false) }
  let(:target_team) { create(:team, account: account, allow_auto_assign: false) }
  let(:source_agent) { create(:user, account: account, role: :agent, auto_offline: false) }
  let(:target_agent) { create(:user, account: account, role: :agent, auto_offline: false) }
  let(:conversation) do
    create(
      :conversation,
      account: account,
      inbox: inbox,
      team: source_team,
      assignee: source_agent,
      waiting_since: 10.minutes.ago
    )
  end

  before do
    account.disable_features!('assignment_v2')
    create(:inbox_member, inbox: inbox, user: source_agent)
    create(:inbox_member, inbox: inbox, user: target_agent)
    create(:team_member, team: source_team, user: source_agent)
    create(:team_member, team: target_team, user: source_agent)
    create(:team_member, team: target_team, user: target_agent)
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)

    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive_messages(
      job_enabled?: true,
      real_assignment_enabled?: true
    )
  end

  it 'moves the conversation into the unassigned target team queue' do
    transfer_to_target_team

    expect(response).to have_http_status(:success)
    expect(conversation.reload).to have_attributes(
      team_id: target_team.id,
      assignee_id: nil
    )
    expect(conversation.additional_attributes['ibsoft_distribution_source']).to eq('manual_team_transfer')
    expect(Ibsoft::ConversationDistribution::CandidateFinder.new(account: account).perform).to contain_exactly(conversation)
  end

  it 'distributes the transferred conversation in the next assignment execution' do
    allow(OnlineStatusTracker).to receive(:get_available_users)
      .with(account.id)
      .and_return(target_agent.id.to_s => 'online')

    transfer_to_target_team
    result = Ibsoft::ConversationDistribution::AssignmentExecutor.new(account: account).perform

    expect(result[:summary]).to include(scanned: 1, assigned: 1, skipped: 0)
    expect(conversation.reload.assignee).to eq(target_agent)
  end

  it 'preserves the assignee when the current team is selected again' do
    transfer_to_team(source_team)

    expect(response).to have_http_status(:success)
    expect(conversation.reload).to have_attributes(
      team_id: source_team.id,
      assignee_id: source_agent.id
    )
  end

  it 'clears the complete AI owner when a manual team transfer enters private distribution' do
    agent_bot = create(:agent_bot, account: account)
    owner_attribute = conversation.respond_to?(:ai_assignee=) ? :ai_assignee : :assignee_agent_bot
    conversation.update!({ :status => :pending, :assignee => nil, owner_attribute => agent_bot })

    transfer_to_target_team

    expect(response).to have_http_status(:success)
    conversation.reload
    expect(conversation).to have_attributes(
      team: target_team,
      assignee: nil,
      assignee_agent_bot: nil
    )
    expect(conversation.ai_assignee).to be_nil if conversation.respond_to?(:ai_assignee)
    expect(conversation.ai_assignee_type).to be_nil if conversation.has_attribute?(:ai_assignee_type)
    expect(conversation.additional_attributes['ibsoft_distribution_source']).to eq('manual_team_transfer')
  end

  it 'marks a team transfer requested by an agent bot as a system transfer' do
    agent_bot = create(:agent_bot, account: account)
    create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)

    post(
      api_v1_account_conversation_assignments_url(
        account_id: account.id,
        conversation_id: conversation.display_id
      ),
      params: { team_id: target_team.id },
      headers: { api_access_token: agent_bot.access_token.token },
      as: :json
    )

    expect(response).to have_http_status(:success)
    expect(conversation.reload).to have_attributes(team: target_team)
    expect(conversation.additional_attributes['ibsoft_distribution_source']).to eq('system_team_transfer')
  end

  private

  def transfer_to_target_team
    transfer_to_team(target_team)
  end

  def transfer_to_team(team)
    post(
      api_v1_account_conversation_assignments_url(
        account_id: account.id,
        conversation_id: conversation.display_id
      ),
      params: { team_id: team.id },
      headers: source_agent.create_new_auth_token,
      as: :json
    )
  end
end

require 'rails_helper'

RSpec.describe 'Ibsoft conversation queue returns', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let(:source_team) { create(:team, account: account, allow_auto_assign: false) }
  let(:target_team) { create(:team, account: account, allow_auto_assign: false) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) do
    create(
      :conversation,
      account: account,
      inbox: inbox,
      team: source_team,
      assignee: agent,
      first_reply_created_at: 10.minutes.ago
    )
  end

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:team_member, team: source_team, user: agent)
    create(:team_member, team: target_team, user: agent)
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)

    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive_messages(
      job_enabled?: true,
      real_assignment_enabled?: true
    )
  end

  it 'returns the current agent conversation to the selected team queue' do
    post return_to_queue_path,
         params: { team_id: target_team.id },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'queued' => true,
      'display_id' => conversation.display_id,
      'team' => include('id' => target_team.id, 'name' => target_team.name)
    )
    expect(conversation.reload).to have_attributes(team_id: target_team.id, assignee_id: nil)
  end

  it 'returns an actionable error when the requester is not the current assignee' do
    other_agent = create(:user, account: account, role: :agent)
    create(:inbox_member, inbox: inbox, user: other_agent)

    post return_to_queue_path,
         params: { team_id: source_team.id },
         headers: other_agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq('error' => 'queue_return_actor_not_assignee')
    expect(conversation.reload.assignee).to eq(agent)
  end

  it 'turns native self-unassignment into a queue return when distribution is active' do
    post assignment_path,
         params: { assignee_id: nil },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.reload.assignee).to be_nil
    expect(conversation.additional_attributes['ibsoft_distribution_source_reason']).to eq('agent_returned_to_queue')
    expect(Ibsoft::ConversationDistribution::CandidateFinder.new(account: account).perform).to contain_exactly(conversation)
  end

  it 'keeps the native self-unassignment fallback when custom distribution is unavailable' do
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:job_enabled?).and_return(false)

    post assignment_path,
         params: { assignee_id: nil },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.reload.assignee).to be_nil
    expect(conversation.additional_attributes['ibsoft_distribution_source_reason']).to be_nil
  end

  private

  def return_to_queue_path
    "/api/v1/accounts/#{account.id}/ibsoft/conversation_distribution/" \
      "conversations/#{conversation.display_id}/return_to_queue"
  end

  def assignment_path
    api_v1_account_conversation_assignments_path(
      account_id: account.id,
      conversation_id: conversation.display_id
    )
  end
end

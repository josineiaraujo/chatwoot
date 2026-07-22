require 'rails_helper'

RSpec.describe 'Ibsoft manual conversation assignments', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let(:team) { create(:team, account: account, allow_auto_assign: false) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending) }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
  end

  it 'returns the final conversation state after assigning an agent' do
    post manual_assignment_path,
         params: { assignment_type: 'agent', target_id: agent.id },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'conversation_id' => conversation.display_id,
      'status' => 'open',
      'assignee' => include('id' => agent.id),
      'team' => nil,
      'distribution_enqueued' => false
    )
  end

  it 'returns an actionable error without changing a resolved conversation' do
    conversation.update!(status: :resolved)

    post manual_assignment_path,
         params: { assignment_type: 'team', target_id: team.id },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq('error' => 'manual_assignment_resolved')
    expect(conversation.reload).to have_attributes(status: 'resolved', team_id: nil)
  end

  it 'does not allow assigning a team from another account' do
    other_team = create(:team)

    post manual_assignment_path,
         params: { assignment_type: 'team', target_id: other_team.id },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq('error' => 'manual_assignment_team_not_found')
  end

  it 'rejects malformed targets without interpreting them as unassignment' do
    conversation.update!(assignee: agent)

    post manual_assignment_path,
         params: { assignment_type: 'agent', target_id: 'invalid' },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq('error' => 'manual_assignment_invalid_target')
    expect(conversation.reload.assignee).to eq(agent)
  end

  it 'does not assign an agent without inbox access' do
    unavailable_agent = create(:user, account: account, role: :agent)

    post manual_assignment_path,
         params: { assignment_type: 'agent', target_id: unavailable_agent.id },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq('error' => 'manual_assignment_agent_not_found')
    expect(conversation.reload.assignee).to be_nil
  end

  it 'does not allow a regular agent to transfer a conversation that already has an assignee' do
    assigned_agent = create(:user, account: account, role: :agent)
    conversation.update!(assignee: assigned_agent)

    post manual_assignment_path,
         params: { assignment_type: 'team', target_id: team.id },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq('error' => 'manual_assignment_assigned_forbidden')
    expect(conversation.reload).to have_attributes(assignee_id: assigned_agent.id, team_id: nil)
  end

  it 'allows an administrator to transfer a conversation that already has an assignee' do
    administrator = create(:user, account: account, role: :administrator)
    assigned_agent = create(:user, account: account, role: :agent)
    conversation.update!(assignee: assigned_agent)

    post manual_assignment_path,
         params: { assignment_type: 'agent', target_id: administrator.id },
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.reload.assignee).to eq(administrator)
  end

  private

  def manual_assignment_path
    "/api/v1/accounts/#{account.id}/ibsoft/conversation_distribution/" \
      "conversations/#{conversation.display_id}/manual_assignment"
  end
end

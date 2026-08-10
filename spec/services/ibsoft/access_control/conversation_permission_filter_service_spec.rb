require 'rails_helper'

RSpec.describe Ibsoft::AccessControl::ConversationPermissionFilterService do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:inaccessible_inbox) { create(:inbox, account: account) }
  let!(:mine) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
  let!(:unassigned) { create(:conversation, account: account, inbox: inbox, assignee: nil) }
  let!(:assigned_to_other) { create(:conversation, account: account, inbox: inbox, assignee: other_agent) }
  let!(:assigned_to_agent_bot) do
    create(:conversation, account: account, inbox: inbox, assignee_agent_bot: create(:agent_bot, account: account))
  end
  let!(:inaccessible_agent_bot_conversation) do
    create(:conversation, account: account, inbox: inaccessible_inbox, assignee_agent_bot: create(:agent_bot, account: account))
  end

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    create(:inbox_member, user: other_agent, inbox: inbox)
  end

  it 'filters to assigned conversations for participating profiles' do
    create_profile_with_permissions(['conversation_participating_manage'])

    result = described_filter

    expect(result).to contain_exactly(mine)
  end

  it 'filters to unassigned and assigned conversations for unassigned management profiles' do
    create_profile_with_permissions(['conversation_unassigned_manage'])

    result = described_filter

    expect(result).to contain_exactly(mine, unassigned, assigned_to_agent_bot)
  end

  it 'keeps all accessible conversations for full conversation management profiles' do
    create_profile_with_permissions(['conversation_manage'])

    result = described_filter

    expect(result).to contain_exactly(mine, unassigned, assigned_to_other, assigned_to_agent_bot)
  end

  it 'does not expose AgentBot conversations from inaccessible inboxes' do
    create_profile_with_permissions(['conversation_unassigned_manage'])

    expect(described_filter).not_to include(inaccessible_agent_bot_conversation)
  end

  private

  def described_filter
    Conversations::PermissionFilterService.new(account.conversations, agent, account).perform
  end

  def create_profile_with_permissions(permissions)
    role = create(:ibsoft_access_control_role, account: account, permissions: permissions)
    create(:ibsoft_access_control_role_assignment, account: account, role: role, user: agent)
  end
end

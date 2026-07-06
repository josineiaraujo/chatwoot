require 'rails_helper'

RSpec.describe Ibsoft::AccessControl::UnreadCountsCounter do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:store) { Conversations::UnreadCounts::Store }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
  end

  after do
    store.clear_account!(account.id)
  end

  it 'uses assignment-mode counts for Ibsoft participating profiles' do
    role = create(
      :ibsoft_access_control_role,
      account: account,
      permissions: ['conversation_participating_manage']
    )
    create(:ibsoft_access_control_role_assignment, account: account, role: role, user: agent)

    create_unread_conversation(account: account, inbox: inbox, assignee: agent)
    create_unread_conversation(account: account, inbox: inbox)

    result = Conversations::UnreadCounts::Counter.new(account: account, user: agent).perform

    expect(result).to eq(
      all_count: 1,
      inboxes: { inbox.id.to_s => 1 },
      labels: {},
      teams: {}
    )
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::AccessControl::AccountUserPermissions do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:account_user) { account.account_users.find_by!(user: agent) }

  after do
    Ibsoft::AccessControl::PermissionRequestCache.reset
  end

  it 'is prepended without changing the native user serializer' do
    expect(AccountUser.ancestors).to include(described_class)
  end

  it 'combines native and private permissions' do
    role = create(:ibsoft_access_control_role, account: account, permissions: ['ibsoft_message_broadcast_manage'])
    create(:ibsoft_access_control_role_assignment, account: account, role: role, user: agent)

    expect(account_user.permissions).to contain_exactly(
      'agent',
      'ibsoft_message_broadcast_manage',
      'ibsoft_access_role',
      'custom_role'
    )
  end

  it 'invalidates the request cache after assigning a role' do
    expect(account_user.permissions).to eq(['agent'])

    role = create(:ibsoft_access_control_role, account: account, permissions: ['conversation_manage'])
    create(:ibsoft_access_control_role_assignment, account: account, role: role, user: agent)

    expect(account_user.permissions).to include('conversation_manage')
  end

  it 'loads role assignments once when serializing memberships from several accounts' do
    second_account = create(:account)
    second_membership = create(:account_user, account: second_account, user: agent)
    queries = []
    subscriber = lambda do |_name, _started, _finished, _id, payload|
      next if payload[:cached]
      next unless payload[:sql].include?('ibsoft_access_control_role_assignments')

      queries << payload[:sql]
    end

    ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
      account_user.permissions
      second_membership.permissions
    end

    expect(queries.size).to eq(1)
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::AccessControl::PermissionResolver do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:account_user) { account.account_users.find_by!(user: agent) }

  it 'returns no permissions when the agent has no Ibsoft profile' do
    expect(described_class.permissions_for(account_user)).to be_empty
  end

  it 'returns role permissions and dashboard markers' do
    role = create(
      :ibsoft_access_control_role,
      account: account,
      permissions: %w[conversation_manage ibsoft_chathub_settings_manage]
    )
    create(:ibsoft_access_control_role_assignment, account: account, role: role, user: agent)

    expect(described_class.permissions_for(account_user)).to contain_exactly(
      'conversation_manage',
      'ibsoft_chathub_settings_manage',
      'ibsoft_access_role',
      'custom_role'
    )
  end

  it 'allows administrators without an Ibsoft profile' do
    admin = create(:user, :administrator, account: account)
    admin_account_user = account.account_users.find_by!(user: admin)

    expect(described_class.permission?(admin_account_user, 'report_manage')).to be(true)
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::Permission do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:account_user) { account.account_users.find_by!(user: agent) }

  it 'does not grant access to agents without the permission' do
    expect(described_class.can_manage?(account_user)).to be(false)
  end

  it 'allows administrators without an Ibsoft profile' do
    admin = create(:user, :administrator, account: account)
    admin_account_user = account.account_users.find_by!(user: admin)

    expect(described_class.can_manage?(admin_account_user)).to be(true)
  end

  it 'allows agents through an Ibsoft access profile' do
    role = create(
      :ibsoft_access_control_role,
      account: account,
      permissions: [described_class::PERMISSION]
    )
    create(:ibsoft_access_control_role_assignment, account: account, role: role, user: agent)

    expect(described_class.can_manage?(account_user)).to be(true)
  end

  it 'does not reuse a permission assigned in another account' do
    other_account = create(:account)
    create(:account_user, account: other_account, user: agent)
    role = create(
      :ibsoft_access_control_role,
      account: account,
      permissions: [described_class::PERMISSION]
    )
    create(:ibsoft_access_control_role_assignment, account: account, role: role, user: agent)

    other_account_user = other_account.account_users.find_by!(user: agent)

    expect(described_class.can_manage?(other_account_user)).to be(false)
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::SupervisorPermission do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:account_user) { account.account_users.find_by!(user: agent) }

  it 'grants no extra permissions by default' do
    expect(described_class.permissions_for(account_user)).to be_empty
    expect(described_class.can_read?(account_user)).to be(false)
  end

  it 'allows administrators even without a supervisor record' do
    admin = create(:user, :administrator, account: account)
    admin_account_user = account.account_users.find_by!(user: admin)

    expect(described_class.can_read?(admin_account_user)).to be(true)
  end

  it 'allows agents through an Ibsoft access profile' do
    role = create(
      :ibsoft_access_control_role,
      account: account,
      permissions: [described_class::PERMISSION]
    )
    create(:ibsoft_access_control_role_assignment, account: account, role: role, user: agent)

    expect(described_class.can_read?(account_user)).to be(true)
  end
end

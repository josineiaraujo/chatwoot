require 'rails_helper'

RSpec.describe Ibsoft::AccessControl::RoleAssignment do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:role) { create(:ibsoft_access_control_role, account: account) }

  it 'allows one role assignment per user in an account' do
    create(:ibsoft_access_control_role_assignment, account: account, role: role, user: user)
    duplicate = build(:ibsoft_access_control_role_assignment, account: account, role: role, user: user)

    expect(duplicate).not_to be_valid
  end

  it 'rejects roles from other accounts' do
    other_role = create(:ibsoft_access_control_role, account: other_account)
    assignment = build(:ibsoft_access_control_role_assignment, account: account, role: other_role, user: user)

    expect(assignment).not_to be_valid
    expect(assignment.errors[:role]).to be_present
  end
end

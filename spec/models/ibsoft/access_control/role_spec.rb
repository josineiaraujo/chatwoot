require 'rails_helper'

RSpec.describe Ibsoft::AccessControl::Role do
  let(:account) { create(:account) }

  it 'accepts known permissions' do
    role = build(
      :ibsoft_access_control_role,
      account: account,
      permissions: %w[conversation_manage ibsoft_chathub_settings_manage]
    )

    expect(role).to be_valid
  end

  it 'rejects unknown permissions' do
    role = build(
      :ibsoft_access_control_role,
      account: account,
      permissions: ['unknown_permission']
    )

    expect(role).not_to be_valid
    expect(role.errors[:permissions]).to be_present
  end
end

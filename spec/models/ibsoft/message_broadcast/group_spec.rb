require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::Group do
  it 'requires a unique name per account' do
    group = create(:ibsoft_message_broadcast_group, name: 'Comercial')
    duplicate = build(:ibsoft_message_broadcast_group, account: group.account, name: 'Comercial')

    expect(duplicate).not_to be_valid
  end

  it 'exposes a compact payload without member data' do
    group = create(:ibsoft_message_broadcast_group, name: 'Avisos')
    create(:ibsoft_message_broadcast_group_member, group: group)

    expect(group.payload).to include(
      id: group.id,
      name: 'Avisos',
      erp_provider: 'ixc',
      members_count: 1
    )
  end
end

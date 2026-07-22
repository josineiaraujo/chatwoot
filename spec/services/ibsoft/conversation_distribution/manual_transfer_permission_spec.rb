require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::ManualTransferPermission do
  let(:account) { create(:account) }
  let(:assigned_agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, assignee: assigned_agent) }

  it 'blocks a regular agent when the conversation already has a human assignee' do
    actor = create(:user, account: account, role: :agent)

    permission = described_class.new(conversation: conversation, actor: actor)

    expect(permission.allowed?).to be(false)
  end

  it 'allows an administrator when the conversation already has a human assignee' do
    actor = create(:user, account: account, role: :administrator)

    permission = described_class.new(conversation: conversation, actor: actor)

    expect(permission.allowed?).to be(true)
  end

  it 'allows the assigned agent to transfer their own conversation' do
    permission = described_class.new(conversation: conversation, actor: assigned_agent)

    expect(permission.allowed?).to be(true)
  end

  it 'allows a regular agent when the conversation has no human assignee' do
    actor = create(:user, account: account, role: :agent)
    conversation.update!(assignee: nil)

    permission = described_class.new(conversation: conversation, actor: actor)

    expect(permission.allowed?).to be(true)
  end

  it 'blocks a user outside the conversation account even when it is unassigned' do
    conversation.update!(assignee: nil)
    outsider = create(:user)

    permission = described_class.new(conversation: conversation, actor: outsider)

    expect(permission.allowed?).to be(false)
  end
end

require 'rails_helper'

RSpec.describe Ibsoft::Conversation::ResolvedAttentionNotificationCleanup do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:other_conversation) { create(:conversation, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:other_agent) { create(:user, account: account) }

  it 'removes notifications tied to the resolved conversation' do
    assignment_notification = create(
      :notification,
      account: account,
      user: agent,
      primary_actor: conversation,
      notification_type: 'conversation_assignment',
      read_at: nil
    )
    participating_notification = create(
      :notification,
      account: account,
      user: other_agent,
      primary_actor: conversation,
      notification_type: 'participating_conversation_new_message',
      read_at: nil
    )
    read_notification = create(
      :notification,
      account: account,
      user: agent,
      primary_actor: conversation,
      notification_type: 'assigned_conversation_new_message',
      read_at: 1.hour.ago
    )
    other_conversation_notification = create(
      :notification,
      account: account,
      user: agent,
      primary_actor: other_conversation,
      notification_type: 'conversation_assignment',
      read_at: nil
    )

    result = described_class.new(conversation: conversation).perform

    expect(result).to eq(removed_count: 3)
    expect(Notification.exists?(assignment_notification.id)).to be(false)
    expect(Notification.exists?(participating_notification.id)).to be(false)
    expect(Notification.exists?(read_notification.id)).to be(false)
    expect(Notification.exists?(other_conversation_notification.id)).to be(true)
  end

  it 'does nothing without a conversation' do
    expect(described_class.new(conversation: nil).perform).to eq(removed_count: 0)
  end
end

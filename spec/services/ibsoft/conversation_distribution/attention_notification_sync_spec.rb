require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::AttentionNotificationSync do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:previous_assignee) { create(:user, account: account) }
  let(:new_assignee) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: new_assignee) }

  before do
    create(:inbox_member, inbox: inbox, user: previous_assignee)
    create(:inbox_member, inbox: inbox, user: new_assignee)
  end

  it 'removes unread assignee attention notifications from the previous assignee' do
    assignment_notification = create(
      :notification,
      account: account,
      user: previous_assignee,
      primary_actor: conversation,
      notification_type: 'conversation_assignment',
      read_at: nil
    )
    new_message_notification = create(
      :notification,
      account: account,
      user: previous_assignee,
      primary_actor: conversation,
      notification_type: 'assigned_conversation_new_message',
      read_at: nil
    )
    participating_notification = create(
      :notification,
      account: account,
      user: previous_assignee,
      primary_actor: conversation,
      notification_type: 'participating_conversation_new_message',
      read_at: nil
    )
    mention_notification = create(
      :notification,
      account: account,
      user: previous_assignee,
      primary_actor: conversation,
      notification_type: 'conversation_mention',
      read_at: nil
    )

    result = described_class.new(
      account: account,
      conversation: conversation,
      previous_assignee: previous_assignee,
      new_assignee: new_assignee
    ).perform

    expect(result).to eq(removed_count: 3)
    expect(Notification.exists?(assignment_notification.id)).to be(false)
    expect(Notification.exists?(new_message_notification.id)).to be(false)
    expect(Notification.exists?(participating_notification.id)).to be(false)
    expect(Notification.exists?(mention_notification.id)).to be(true)
  end

  it 'keeps read history notifications from the previous assignee' do
    read_notification = create(
      :notification,
      account: account,
      user: previous_assignee,
      primary_actor: conversation,
      notification_type: 'conversation_assignment',
      read_at: 1.hour.ago
    )

    result = described_class.new(
      account: account,
      conversation: conversation,
      previous_assignee: previous_assignee,
      new_assignee: new_assignee
    ).perform

    expect(result).to eq(removed_count: 0)
    expect(Notification.exists?(read_notification.id)).to be(true)
  end
end

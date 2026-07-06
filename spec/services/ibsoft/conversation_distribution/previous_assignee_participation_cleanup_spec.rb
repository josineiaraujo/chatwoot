require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::PreviousAssigneeParticipationCleanup do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: new_assignee) }
  let(:previous_assignee) { create(:user, account: account) }
  let(:new_assignee) { create(:user, account: account) }

  before do
    create(:inbox_member, inbox: inbox, user: previous_assignee)
    create(:inbox_member, inbox: inbox, user: new_assignee)
  end

  it 'removes the previous assignee from conversation participants' do
    previous_participant = create(:conversation_participant, account: account, conversation: conversation, user: previous_assignee)
    new_participant = create(:conversation_participant, account: account, conversation: conversation, user: new_assignee)

    result = described_class.new(
      account: account,
      conversation: conversation,
      previous_assignee: previous_assignee,
      new_assignee: new_assignee
    ).perform

    expect(result).to eq(removed_count: 1)
    expect(ConversationParticipant.exists?(previous_participant.id)).to be(false)
    expect(ConversationParticipant.exists?(new_participant.id)).to be(true)
  end

  it 'does nothing when the assignee did not change' do
    previous_participant = create(:conversation_participant, account: account, conversation: conversation, user: previous_assignee)

    result = described_class.new(
      account: account,
      conversation: conversation,
      previous_assignee: previous_assignee,
      new_assignee: previous_assignee
    ).perform

    expect(result).to eq(removed_count: 0)
    expect(ConversationParticipant.exists?(previous_participant.id)).to be(true)
  end
end

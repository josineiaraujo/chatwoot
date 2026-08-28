require 'rails_helper'

RSpec.describe Ibsoft::AfterHours::WaitReconciler do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:conversation) { create(:conversation, account: account, team: team, status: :open, assignee: nil) }
  let!(:wait) do
    create(
      :ibsoft_after_hours_wait,
      account: account,
      conversation: conversation,
      team: team,
      after_hours_policy: create(:ibsoft_after_hours_policy, account: account)
    )
  end

  it 'keeps an active wait while the conversation remains unassigned in the same department' do
    result = described_class.new(conversation: conversation).perform

    expect(result).to be_nil
    expect(wait.reload).to be_active
  end

  it 'does nothing when the conversation has no wait' do
    wait.destroy!

    expect(described_class.new(conversation: conversation).perform).to be_nil
  end

  it 'cancels the wait when an agent assumes the conversation' do
    conversation.update!(assignee: create(:user, account: account))

    result = described_class.new(conversation: conversation).perform

    expect(result).to be_nil
    expect(wait.reload).to have_attributes(status: 'cancelled', finished_at: be_present)
  end

  it 'cancels the wait when the conversation moves to another department' do
    conversation.update!(team: create(:team, account: account))

    described_class.new(conversation: conversation).perform

    expect(wait.reload).to have_attributes(status: 'cancelled', finished_at: be_present)
  end

  it 'cancels the wait when the conversation is resolved externally' do
    conversation.update!(status: :resolved)

    described_class.new(conversation: conversation).perform

    expect(wait.reload).to have_attributes(status: 'cancelled', finished_at: be_present)
  end

  it 'does not overwrite a wait that was already completed' do
    wait.update!(status: 'exited', finished_at: Time.current)

    described_class.new(conversation: conversation).perform

    expect(wait.reload.status).to eq('exited')
  end
end

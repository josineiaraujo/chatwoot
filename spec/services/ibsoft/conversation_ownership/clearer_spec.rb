require 'rails_helper'

RSpec.describe Ibsoft::ConversationOwnership::Clearer do
  it 'clears human and legacy bot ownership' do
    account = create(:account)
    conversation = create(
      :conversation,
      account: account,
      assignee: create(:user, account: account),
      assignee_agent_bot: create(:agent_bot, account: account)
    )

    described_class.perform(conversation)
    conversation.save!

    expect(conversation.reload).to have_attributes(assignee_id: nil, assignee_agent_bot_id: nil)
  end

  it 'clears the typed AI owner when that API is available' do
    conversation_class = Struct.new(:assignee, :assignee_agent_bot, :ai_assignee, :ai_assignee_type) do
      def ai_assignee=(owner)
        self[:ai_assignee] = owner
        self[:ai_assignee_type] = owner&.class&.name
      end
    end
    conversation = conversation_class.new(Object.new, Object.new, Object.new, 'AgentBot')

    described_class.perform(conversation)

    expect(conversation).to have_attributes(
      assignee: nil,
      assignee_agent_bot: nil,
      ai_assignee: nil,
      ai_assignee_type: nil
    )
  end
end

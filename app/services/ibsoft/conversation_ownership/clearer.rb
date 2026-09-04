class Ibsoft::ConversationOwnership::Clearer
  def self.perform(conversation)
    conversation.assignee = nil
    conversation.assignee_agent_bot = nil
    conversation.ai_assignee = nil if conversation.respond_to?(:ai_assignee=)
    conversation
  end
end

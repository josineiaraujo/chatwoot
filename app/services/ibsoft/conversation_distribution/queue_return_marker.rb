class Ibsoft::ConversationDistribution::QueueReturnMarker
  REASON = 'agent_returned_to_queue'.freeze

  def self.apply_first_reply_scope(scope)
    scope.where(
      'conversations.first_reply_created_at IS NULL OR conversations.additional_attributes @> ?',
      { Ibsoft::ConversationDistribution::SourceMarker::REASON_KEY => REASON }.to_json
    )
  end

  def self.marked?(conversation)
    conversation.additional_attributes&.fetch(
      Ibsoft::ConversationDistribution::SourceMarker::REASON_KEY,
      nil
    ) == REASON
  end

  def self.consume(attributes)
    attributes.deep_dup.except(Ibsoft::ConversationDistribution::SourceMarker::REASON_KEY)
  end
end

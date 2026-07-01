class Ibsoft::ConversationDistribution::SourceMarker
  ATTRIBUTE_KEY = Ibsoft::ConversationDistribution::SourceResolver::ATTRIBUTE_KEY
  MARKED_AT_KEY = 'ibsoft_distribution_source_marked_at'.freeze
  REASON_KEY = 'ibsoft_distribution_source_reason'.freeze

  def initialize(conversation:, source: nil, reason: nil)
    @conversation = conversation
    @source = source
    @reason = reason
  end

  def assign
    return conversation unless source_known?

    conversation.additional_attributes = marked_attributes
    conversation
  end

  def perform
    assign.save!
  end

  private

  attr_reader :conversation, :source, :reason

  def marked_attributes
    attributes = (conversation.additional_attributes || {}).deep_dup
    attributes[ATTRIBUTE_KEY] = resolved_source
    attributes[MARKED_AT_KEY] = Time.current.iso8601
    attributes[REASON_KEY] = reason if reason.present?
    attributes
  end

  def source_known?
    Ibsoft::ConversationDistribution::SourceResolver::KNOWN_SOURCES.include?(resolved_source)
  end

  def resolved_source
    @resolved_source ||= source.presence || source_from_current_context
  end

  def source_from_current_context
    return 'system_team_transfer' if Current.executed_by.present?
    return 'system_team_transfer' if Current.user.is_a?(AgentBot)

    'manual_team_transfer'
  end
end

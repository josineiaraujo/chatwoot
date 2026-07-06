class Ibsoft::ConversationDistribution::SourceResolver
  ATTRIBUTE_KEY = 'ibsoft_distribution_source'.freeze
  KNOWN_SOURCES = %w[bot_handoff manual_team_transfer system_team_transfer].freeze

  def initialize(conversation:, bot_handoff: false)
    @conversation = conversation
    @bot_handoff = bot_handoff
  end

  def perform
    return source_payload(explicit_source, 'explicit') if known_source?(explicit_source)
    return source_payload('bot_handoff', 'reporting_event') if bot_handoff?

    source_payload(nil, 'unknown')
  end

  private

  attr_reader :conversation

  def explicit_source
    attributes[ATTRIBUTE_KEY] || attributes[ATTRIBUTE_KEY.to_sym]
  end

  def attributes
    conversation.additional_attributes || {}
  end

  def bot_handoff?
    @bot_handoff
  end

  def known_source?(source)
    KNOWN_SOURCES.include?(source)
  end

  def source_payload(source, confidence)
    {
      source: source,
      confidence: confidence
    }
  end
end

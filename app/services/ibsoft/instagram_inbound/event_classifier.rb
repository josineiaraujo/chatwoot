# frozen_string_literal: true

class Ibsoft::InstagramInbound::EventClassifier
  STORY_ATTACHMENT_TYPES = %w[story_mention].freeze
  REEL_AND_STORY_ATTACHMENT_TYPES = %w[ig_reel reel ig_story].freeze
  POST_ATTACHMENT_TYPES = %w[ig_post share].freeze

  def initialize(messaging)
    @messaging = messaging.with_indifferent_access
  end

  def category
    return :story_interactions if story_reply? || attachment_type_in?(STORY_ATTACHMENT_TYPES)
    return :shared_reels_and_stories if attachment_type_in?(REEL_AND_STORY_ATTACHMENT_TYPES)
    return :shared_posts if attachment_type_in?(POST_ATTACHMENT_TYPES)

    nil
  end

  private

  attr_reader :messaging

  def message
    messaging[:message] || {}
  end

  def story_reply?
    message.dig(:reply_to, :story).present?
  end

  def attachment_type_in?(types)
    attachments.any? { |attachment| types.include?(attachment[:type].to_s) }
  end

  def attachments
    Array(message[:attachments]).map(&:with_indifferent_access)
  end
end

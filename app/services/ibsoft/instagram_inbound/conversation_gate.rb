# frozen_string_literal: true

class Ibsoft::InstagramInbound::ConversationGate
  SETTING_BY_CATEGORY = {
    story_interactions: :create_from_story_interactions,
    shared_reels_and_stories: :create_from_shared_reels_and_stories,
    shared_posts: :create_from_shared_posts
  }.freeze

  def initialize(channel:, messaging:)
    @channel = channel
    @messaging = messaging.with_indifferent_access
  end

  def allow?
    return true if outgoing_echo?

    setting = SETTING_BY_CATEGORY[classifier.category]
    return true if setting.blank?
    return true if active_conversation?

    policy.public_send(setting)
  rescue StandardError => e
    report_failure(e)
    true
  end

  private

  attr_reader :channel, :messaging

  def classifier
    @classifier ||= Ibsoft::InstagramInbound::EventClassifier.new(messaging)
  end

  def inbox
    @inbox ||= channel.inbox
  end

  def policy
    @policy ||= Ibsoft::InstagramInbound::Policy.find_or_initialize_by(
      account_id: inbox.account_id,
      inbox_id: inbox.id
    )
  end

  def outgoing_echo?
    messaging.dig(:message, :is_echo).present?
  end

  def active_conversation?
    contact_inbox = inbox.contact_inboxes.find_by(source_id: contact_source_id)
    return false if contact_inbox.blank?

    inbox.conversations
         .where(contact_id: contact_inbox.contact_id)
         .where.not(status: :resolved)
         .exists?
  end

  def contact_source_id
    messaging.dig(:sender, :id).to_s
  end

  def report_failure(error)
    Rails.error.report(
      error,
      handled: true,
      context: {
        ibsoft_module: 'instagram_inbound',
        account_id: inbox&.account_id,
        inbox_id: inbox&.id
      }
    )
  end
end

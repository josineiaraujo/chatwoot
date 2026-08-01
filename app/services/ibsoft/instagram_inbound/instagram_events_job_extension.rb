# frozen_string_literal: true

module Ibsoft::InstagramInbound::InstagramEventsJobExtension
  private

  def message(messaging, channel)
    return unless Ibsoft::InstagramInbound::ConversationGate.new(channel: channel, messaging: messaging).allow?

    super
  end
end

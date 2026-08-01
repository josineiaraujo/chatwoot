# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ibsoft::InstagramInbound::ConversationGate do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_instagram, account: account) }
  let(:inbox) { channel.inbox }

  def messaging_from(factory, sender_id: SecureRandom.hex(8))
    build(factory, sender_id: sender_id).with_indifferent_access.dig(:entry, 0, :messaging, 0)
  end

  def create_policy(attributes = {})
    create(
      :ibsoft_instagram_inbound_policy,
      {
        account: account,
        inbox: inbox,
        create_from_story_interactions: false,
        create_from_shared_reels_and_stories: false,
        create_from_shared_posts: false
      }.merge(attributes)
    )
  end

  it 'allows ordinary direct messages without loading a policy' do
    allow(Ibsoft::InstagramInbound::Policy).to receive(:find_or_initialize_by)
    gate = described_class.new(channel: channel, messaging: messaging_from(:instagram_message_create_event))

    expect(gate.allow?).to be(true)
    expect(Ibsoft::InstagramInbound::Policy).not_to have_received(:find_or_initialize_by)
  end

  it 'allows categorized interactions when no saved policy exists' do
    gate = described_class.new(channel: channel, messaging: messaging_from(:instagram_story_reply_event))

    expect(gate.allow?).to be(true)
  end

  {
    instagram_story_reply_event: :create_from_story_interactions,
    instagram_story_mention_event: :create_from_story_interactions,
    instagram_shared_reel_event: :create_from_shared_reels_and_stories,
    instagram_ig_story_event: :create_from_shared_reels_and_stories,
    instagram_ig_post_event: :create_from_shared_posts,
    instagram_message_attachment_event: :create_from_shared_posts
  }.each do |factory, setting|
    it "blocks #{factory} when #{setting} is disabled and there is no active conversation" do
      create_policy(setting => false)
      gate = described_class.new(channel: channel, messaging: messaging_from(factory))

      expect(gate.allow?).to be(false)
    end
  end

  %w[open pending snoozed].each do |status|
    it "allows a Story interaction in an existing #{status} conversation" do
      sender_id = SecureRandom.hex(8)
      create_policy
      contact = create(:contact, account: account)
      contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox, source_id: sender_id)
      create(
        :conversation,
        account: account,
        inbox: inbox,
        contact: contact,
        contact_inbox: contact_inbox,
        status: status
      )
      gate = described_class.new(
        channel: channel,
        messaging: messaging_from(:instagram_story_reply_event, sender_id: sender_id)
      )

      expect(gate.allow?).to be(true)
    end
  end

  it 'does not treat a resolved conversation as active' do
    sender_id = SecureRandom.hex(8)
    create_policy
    contact = create(:contact, account: account)
    contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox, source_id: sender_id)
    create(
      :conversation,
      account: account,
      inbox: inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      status: :resolved
    )
    gate = described_class.new(
      channel: channel,
      messaging: messaging_from(:instagram_story_reply_event, sender_id: sender_id)
    )

    expect(gate.allow?).to be(false)
  end

  it 'allows outgoing echo events regardless of the policy' do
    create_policy
    messaging = messaging_from(:instagram_story_mention_event)
    messaging[:message][:is_echo] = true

    expect(described_class.new(channel: channel, messaging: messaging).allow?).to be(true)
  end

  it 'applies the policy to Instagram events received through a Facebook Page channel' do
    facebook_channel = create(:channel_instagram_fb_page, account: account, instagram_id: SecureRandom.hex(8))
    facebook_inbox = create(:inbox, account: account, channel: facebook_channel)
    create(
      :ibsoft_instagram_inbound_policy,
      account: account,
      inbox: facebook_inbox,
      create_from_shared_posts: false
    )
    gate = described_class.new(channel: facebook_channel, messaging: messaging_from(:instagram_ig_post_event))

    expect(gate.allow?).to be(false)
  end

  it 'fails open without storing or logging the webhook payload' do
    allow(Ibsoft::InstagramInbound::EventClassifier).to receive(:new).and_raise(StandardError, 'failure')
    allow(Rails.error).to receive(:report)
    messaging = messaging_from(:instagram_story_reply_event)

    expect(described_class.new(channel: channel, messaging: messaging).allow?).to be(true)
    expect(Rails.error).to have_received(:report).with(
      an_instance_of(StandardError),
      handled: true,
      context: hash_including(
        ibsoft_module: 'instagram_inbound',
        account_id: account.id,
        inbox_id: inbox.id
      )
    )
  end
end

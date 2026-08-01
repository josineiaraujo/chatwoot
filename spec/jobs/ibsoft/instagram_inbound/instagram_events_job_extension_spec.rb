# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ibsoft::InstagramInbound::InstagramEventsJobExtension do
  let(:account) { create(:account) }
  let(:channel) do
    create(
      :channel_instagram,
      account: account,
      instagram_id: 'chatwoot-app-user-id-1'
    )
  end
  let(:inbox) { channel.inbox }

  it 'keeps the extension connected to the Instagram job contract' do
    expect(Webhooks::InstagramEventsJob.ancestors).to include(
      described_class
    )
    expect(described_class.private_instance_methods(false)).to contain_exactly(:message)
  end

  {
    instagram_story_reply_event: :create_from_story_interactions,
    instagram_story_mention_event: :create_from_story_interactions,
    instagram_shared_reel_event: :create_from_shared_reels_and_stories,
    instagram_ig_story_event: :create_from_shared_reels_and_stories,
    instagram_ig_post_event: :create_from_shared_posts,
    instagram_message_attachment_event: :create_from_shared_posts
  }.each do |factory, setting|
    it "blocks #{factory} before creating contact, conversation or message" do
      create(
        :ibsoft_instagram_inbound_policy,
        account: account,
        inbox: inbox,
        **{ setting => false }
      )
      event = build(factory).with_indifferent_access

      Webhooks::InstagramEventsJob.perform_now(event[:entry])

      expect(inbox.contacts).to be_empty
      expect(inbox.conversations).to be_empty
      expect(inbox.messages).to be_empty
    end
  end

  it 'does not load policy state for an ordinary direct message' do
    create(
      :ibsoft_instagram_inbound_policy,
      account: account,
      inbox: inbox,
      create_from_story_interactions: false
    )
    event = build(:instagram_message_create_event).with_indifferent_access
    service = instance_double(Instagram::MessageText, perform: nil)
    allow(Ibsoft::InstagramInbound::Policy).to receive(:find_or_initialize_by)
    allow(Instagram::MessageText).to receive(:new).and_return(service)

    Webhooks::InstagramEventsJob.perform_now(event[:entry])

    expect(Ibsoft::InstagramInbound::Policy).not_to have_received(:find_or_initialize_by)
    expect(Instagram::MessageText).to have_received(:new)
    expect(service).to have_received(:perform)
  end
end

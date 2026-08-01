# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ibsoft::InstagramInbound::EventClassifier do
  def messaging_with(message)
    {
      'sender' => { 'id' => 'instagram-scoped-contact-id' },
      'recipient' => { 'id' => 'instagram-professional-account-id' },
      'timestamp' => 1_752_000_000_000,
      'message' => { 'mid' => 'instagram-message-id' }.merge(message)
    }
  end

  it 'classifies a Story reply using the Meta reply_to.story payload' do
    messaging = messaging_with(
      'text' => 'Story reply',
      'reply_to' => {
        'story' => {
          'id' => 'story-id',
          'url' => 'https://lookaside.instagram.example/story'
        }
      }
    )

    expect(described_class.new(messaging).category).to eq(:story_interactions)
  end

  it 'classifies a Story mention attachment' do
    messaging = messaging_with(
      'attachments' => [
        {
          'type' => 'story_mention',
          'payload' => { 'url' => 'https://lookaside.instagram.example/mention' }
        }
      ]
    )

    expect(described_class.new(messaging).category).to eq(:story_interactions)
  end

  %w[ig_reel reel].each do |attachment_type|
    it "classifies the #{attachment_type} Reel attachment used by Meta" do
      messaging = messaging_with(
        'attachments' => [
          {
            'type' => attachment_type,
            'payload' => { 'url' => 'https://lookaside.instagram.example/reel' }
          }
        ]
      )

      expect(described_class.new(messaging).category).to eq(:shared_reels_and_stories)
    end
  end

  it 'classifies the shared Story attachment supported by Chatwoot' do
    messaging = messaging_with(
      'attachments' => [
        {
          'type' => 'ig_story',
          'payload' => {
            'story_media_id' => 'story-media-id',
            'story_media_url' => 'https://lookaside.instagram.example/shared-story'
          }
        }
      ]
    )

    expect(described_class.new(messaging).category).to eq(:shared_reels_and_stories)
  end

  it 'classifies the shared post attachment supported by Chatwoot' do
    messaging = messaging_with(
      'attachments' => [
        {
          'type' => 'ig_post',
          'payload' => {
            'ig_post_media_id' => 'post-media-id',
            'url' => 'https://lookaside.instagram.example/shared-post'
          }
        }
      ]
    )

    expect(described_class.new(messaging).category).to eq(:shared_posts)
  end

  it 'checks every attachment instead of relying on the first one' do
    messaging = messaging_with(
      'attachments' => [
        { 'type' => 'image', 'payload' => { 'url' => 'https://example.test/image' } },
        { 'type' => 'story_mention', 'payload' => { 'url' => 'https://example.test/story' } }
      ]
    )

    expect(described_class.new(messaging).category).to eq(:story_interactions)
  end

  it 'does not classify an ordinary direct message' do
    messaging = messaging_with('text' => 'Ordinary direct message')

    expect(described_class.new(messaging).category).to be_nil
  end

  it 'classifies the generic share payload documented for shared media or posts' do
    messaging = messaging_with(
      'attachments' => [
        {
          'type' => 'share',
          'payload' => { 'url' => 'https://lookaside.instagram.example/share' }
        }
      ]
    )

    expect(described_class.new(messaging).category).to eq(:shared_posts)
  end
end

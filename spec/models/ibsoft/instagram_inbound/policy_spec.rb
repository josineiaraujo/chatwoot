# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ibsoft::InstagramInbound::Policy do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_instagram, account: account) }
  let(:inbox) { channel.inbox }

  it 'uses backwards-compatible defaults' do
    policy = described_class.new(account: account, inbox: inbox)

    expect(policy).to have_attributes(
      create_from_story_interactions: true,
      create_from_shared_reels_and_stories: true,
      create_from_shared_posts: true
    )
  end

  it 'allows one policy per inbox' do
    create(:ibsoft_instagram_inbound_policy, account: account, inbox: inbox)
    duplicate = build(:ibsoft_instagram_inbound_policy, account: account, inbox: inbox)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:inbox_id]).to be_present
  end

  it 'rejects an inbox from another account' do
    foreign_inbox = create(:channel_instagram).inbox
    policy = build(:ibsoft_instagram_inbound_policy, account: account, inbox: foreign_inbox)

    expect(policy).not_to be_valid
    expect(policy.errors[:inbox]).to be_present
  end

  it 'rejects a channel that is not connected to Instagram' do
    web_inbox = create(:inbox, account: account)
    policy = build(:ibsoft_instagram_inbound_policy, account: account, inbox: web_inbox)

    expect(policy).not_to be_valid
    expect(policy.errors[:inbox]).to be_present
  end

  it 'accepts a Facebook Page channel connected to Instagram' do
    facebook_channel = create(:channel_instagram_fb_page, account: account, instagram_id: SecureRandom.hex(8))
    facebook_inbox = create(:inbox, account: account, channel: facebook_channel)

    expect(build(:ibsoft_instagram_inbound_policy, account: account, inbox: facebook_inbox)).to be_valid
  end
end

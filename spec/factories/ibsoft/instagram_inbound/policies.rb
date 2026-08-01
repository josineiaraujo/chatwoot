# frozen_string_literal: true

FactoryBot.define do
  factory :ibsoft_instagram_inbound_policy, class: 'Ibsoft::InstagramInbound::Policy' do
    account
    association :inbox
    create_from_story_interactions { true }
    create_from_shared_reels_and_stories { true }
    create_from_shared_posts { true }
  end
end

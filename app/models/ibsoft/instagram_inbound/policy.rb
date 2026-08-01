# frozen_string_literal: true

# == Schema Information
#
# Table name: ibsoft_instagram_inbound_policies
#
#  id                                   :bigint           not null, primary key
#  create_from_shared_posts             :boolean          default(TRUE), not null
#  create_from_shared_reels_and_stories :boolean          default(TRUE), not null
#  create_from_story_interactions       :boolean          default(TRUE), not null
#  created_at                           :datetime         not null
#  updated_at                           :datetime         not null
#  account_id                           :bigint           not null
#  inbox_id                             :bigint           not null
#
# Indexes
#
#  idx_ibsoft_instagram_inbound_policies_account_inbox  (account_id,inbox_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (inbox_id => inboxes.id) ON DELETE => cascade
#
class Ibsoft::InstagramInbound::Policy < ApplicationRecord
  self.table_name = 'ibsoft_instagram_inbound_policies'

  belongs_to :account
  belongs_to :inbox

  validates :inbox_id, uniqueness: { scope: :account_id }
  validate :inbox_belongs_to_account
  validate :instagram_inbox

  def as_api_json
    {
      inbox_id: inbox_id,
      create_from_story_interactions: create_from_story_interactions,
      create_from_shared_reels_and_stories: create_from_shared_reels_and_stories,
      create_from_shared_posts: create_from_shared_posts
    }
  end

  private

  def inbox_belongs_to_account
    return if inbox.blank? || account.blank? || inbox.account_id == account_id

    errors.add(:inbox, :invalid_account)
  end

  def instagram_inbox
    return if inbox.blank? || inbox.instagram?

    errors.add(:inbox, :not_instagram)
  end
end

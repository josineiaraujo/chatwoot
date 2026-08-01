# frozen_string_literal: true

class CreateIbsoftInstagramInboundPolicies < ActiveRecord::Migration[7.1]
  def change
    create_table :ibsoft_instagram_inbound_policies do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :inbox, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.boolean :create_from_story_interactions, null: false, default: true
      t.boolean :create_from_shared_reels_and_stories, null: false, default: true
      t.boolean :create_from_shared_posts, null: false, default: true
      t.timestamps
    end

    add_index :ibsoft_instagram_inbound_policies,
              [:account_id, :inbox_id],
              unique: true,
              name: 'idx_ibsoft_instagram_inbound_policies_account_inbox'
  end
end

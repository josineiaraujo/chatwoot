# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::InstagramInbound::InboxPolicies', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:channel) { create(:channel_instagram, account: account) }
  let(:inbox) { channel.inbox }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:agent_headers) { { api_access_token: agent.access_token.token } }
  let(:base_url) do
    "/api/v1/accounts/#{account.id}/ibsoft/instagram_inbound/inbox_policies/#{inbox.id}"
  end

  it 'returns enabled defaults without persisting a policy' do
    get base_url, headers: admin_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq(
      'inbox_id' => inbox.id,
      'create_from_story_interactions' => true,
      'create_from_shared_reels_and_stories' => true,
      'create_from_shared_posts' => true
    )
    expect(Ibsoft::InstagramInbound::Policy.where(account: account, inbox: inbox)).not_to exist
  end

  it 'persists and returns the selected settings' do
    patch base_url,
          params: {
            create_from_story_interactions: false,
            create_from_shared_reels_and_stories: true,
            create_from_shared_posts: false
          },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'create_from_story_interactions' => false,
      'create_from_shared_reels_and_stories' => true,
      'create_from_shared_posts' => false
    )
    expect(Ibsoft::InstagramInbound::Policy.find_by(inbox: inbox)).to have_attributes(
      account_id: account.id,
      create_from_story_interactions: false,
      create_from_shared_reels_and_stories: true,
      create_from_shared_posts: false
    )
  end

  it 'blocks regular agents' do
    get base_url, headers: agent_headers, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not expose an inbox from another account' do
    foreign_inbox = create(:channel_instagram).inbox
    foreign_url = "/api/v1/accounts/#{account.id}/ibsoft/instagram_inbound/inbox_policies/#{foreign_inbox.id}"

    get foreign_url, headers: admin_headers, as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'rejects a channel that is not connected to Instagram' do
    web_inbox = create(:inbox, account: account)
    web_url = "/api/v1/accounts/#{account.id}/ibsoft/instagram_inbound/inbox_policies/#{web_inbox.id}"

    get web_url, headers: admin_headers, as: :json

    expect(response).to have_http_status(:not_found)
  end
end

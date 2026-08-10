# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ibsoft::Conversation::BulkActionStatsNotifier do
  subject(:notify) do
    described_class.new(
      account: account,
      user: actor,
      params: params,
      conversations: conversations
    ).perform
  end

  let(:account) { create(:account) }
  let(:actor) { create(:user, account: account, role: :agent) }
  let(:member) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:conversation) { create(:conversation, account: account) }
  let(:conversations) { [conversation] }
  let(:params) { { fields: { status: 'resolved' } } }

  before do
    create(:inbox_member, inbox: conversation.inbox, user: actor)
    create(:inbox_member, inbox: conversation.inbox, user: member)
    administrator
  end

  it 'notifies the actor, affected inbox members and administrators once' do
    expected_tokens = [actor.pubsub_token, member.pubsub_token, administrator.pubsub_token].sort

    expect { notify }.to have_enqueued_job(ActionCableBroadcastJob).with(
      expected_tokens,
      described_class::EVENT_NAME,
      { account_id: account.id }
    )
  end

  it 'does not notify for fields that cannot change conversation counters' do
    params[:fields] = { priority: 'high' }

    expect { notify }.not_to have_enqueued_job(ActionCableBroadcastJob)
  end

  it 'does not notify when no authorized conversation was updated' do
    conversations.clear

    expect { notify }.not_to have_enqueued_job(ActionCableBroadcastJob)
  end
end

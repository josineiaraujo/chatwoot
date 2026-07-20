require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::QueueBroadcast do
  let(:broadcast) { create(:ibsoft_message_broadcast, status: 'draft') }
  let(:sent_by) { create(:user, account: broadcast.account) }

  it 'queues a draft and its pending recipients atomically', :aggregate_failures do
    pending_recipient = create(:ibsoft_message_broadcast_recipient, broadcast: broadcast, status: 'pending')
    skipped_recipient = create(:ibsoft_message_broadcast_recipient, broadcast: broadcast, status: 'skipped')

    result = described_class.new(broadcast: broadcast, sent_by: sent_by).call

    expect(result).to eq(described_class::RESULT_QUEUED)
    expect(broadcast).to have_attributes(status: 'queued', sent_by: sent_by)
    expect(pending_recipient.reload.status).to eq('queued')
    expect(skipped_recipient.reload.status).to eq('skipped')
  end

  it 'allows only one caller to queue the same draft', :aggregate_failures do
    create(:ibsoft_message_broadcast_recipient, broadcast: broadcast, status: 'pending')

    first_result = described_class.new(broadcast: broadcast, sent_by: sent_by).call
    second_result = described_class.new(broadcast: broadcast.reload, sent_by: sent_by).call

    expect(first_result).to eq(described_class::RESULT_QUEUED)
    expect(second_result).to eq(described_class::RESULT_INVALID_STATUS)
  end

  it 'rolls back the broadcast claim when no pending recipient exists', :aggregate_failures do
    create(:ibsoft_message_broadcast_recipient, broadcast: broadcast, status: 'skipped')

    result = described_class.new(broadcast: broadcast, sent_by: sent_by).call

    expect(result).to eq(described_class::RESULT_WITHOUT_RECIPIENTS)
    expect(broadcast.reload).to have_attributes(status: 'draft', sent_by_id: nil)
  end
end

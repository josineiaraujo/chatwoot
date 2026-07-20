require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::RecipientDeliveryClaim do
  let(:recipient) { create(:ibsoft_message_broadcast_recipient, status: 'queued') }

  it 'allows only one worker to claim the recipient', :aggregate_failures do
    first_claim = described_class.new(recipient: recipient)
    second_claim = described_class.new(recipient: recipient.class.find(recipient.id))

    expect(first_claim.acquire).to be(true)
    expect(second_claim.acquire).to be(false)
    expect(recipient.status).to eq('processing')
  end

  it 'does not claim an already terminal recipient' do
    recipient.update!(status: 'sent')

    expect(described_class.new(recipient: recipient).acquire).to be(false)
  end

  it 'marks only an active processing claim as failed', :aggregate_failures do
    claim = described_class.new(recipient: recipient)
    claim.acquire

    claim.fail(StandardError.new('unexpected failure'))

    expect(recipient.reload).to have_attributes(
      status: 'failed',
      error_code: 'unexpected_delivery_error',
      error_message: 'unexpected failure'
    )
  end

  it 'does not overwrite a terminal state when reporting an old claim failure' do
    claim = described_class.new(recipient: recipient)
    claim.acquire
    recipient.update!(status: 'sent')

    claim.fail(StandardError.new('late failure'))

    expect(recipient.reload.status).to eq('sent')
  end
end

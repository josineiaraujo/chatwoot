require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::WhatsappStatusExtension do
  let(:recipient) do
    create(
      :ibsoft_message_broadcast_recipient,
      status: 'accepted',
      meta_message_id: 'wamid.broadcast-1'
    )
  end
  let(:service_class) do
    klass = Class.new do
      attr_reader :native_called

      def initialize(inbox:, status:)
        @inbox = inbox
        @processed_params = { statuses: [status] }
        @native_called = false
      end

      def call
        process_statuses
      end

      private

      attr_reader :inbox

      def process_statuses
        @native_called = true
      end
    end
    klass.prepend(described_class)
    klass
  end

  it 'updates a direct delivery without invoking native message lookup' do
    service = service_class.new(
      inbox: recipient.broadcast.inbox,
      status: { id: recipient.meta_message_id, status: 'delivered' }
    )

    service.call

    expect(service.native_called).to be(false)
    expect(recipient.reload.status).to eq('delivered')
  end

  it 'continues through the native flow for a recorded conversation message' do
    recipient.update!(message: create(:message, account: recipient.broadcast.account))
    service = service_class.new(
      inbox: recipient.broadcast.inbox,
      status: { id: recipient.meta_message_id, status: 'delivered' }
    )

    service.call

    expect(service.native_called).to be(true)
    expect(recipient.reload.status).to eq('delivered')
  end

  it 'delegates unknown Meta message IDs to the native flow' do
    service = service_class.new(
      inbox: recipient.broadcast.inbox,
      status: { id: 'wamid.native', status: 'delivered' }
    )

    service.call

    expect(service.native_called).to be(true)
    expect(recipient.reload.status).to eq('accepted')
  end
end

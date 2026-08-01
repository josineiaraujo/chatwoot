require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::WhatsappStatusExtension do
  let(:delivery) do
    create(
      :ibsoft_external_message_delivery,
      status: 'accepted',
      meta_message_id: 'wamid.external-1'
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

  it 'updates an external delivery without invoking native message lookup' do
    service = service_class.new(
      inbox: delivery.inbox,
      status: { id: delivery.meta_message_id, status: 'delivered' }
    )

    service.call

    expect(service.native_called).to be(false)
    expect(delivery.reload.status).to eq('delivered')
  end

  it 'delegates unknown message IDs to the native Chatwoot flow' do
    service = service_class.new(
      inbox: delivery.inbox,
      status: { id: 'wamid.native-message', status: 'delivered' }
    )

    service.call

    expect(service.native_called).to be(true)
    expect(delivery.reload.status).to eq('accepted')
  end

  it 'updates an external order update without invoking native message lookup' do
    update = create(
      :ibsoft_external_message_order_update,
      status: 'accepted',
      meta_message_id: 'wamid.order-update-1'
    )
    service = service_class.new(
      inbox: update.inbox,
      status: { id: update.meta_message_id, status: 'delivered' }
    )

    service.call

    expect(service.native_called).to be(false)
    expect(update.reload.status).to eq('delivered')
  end

  it 'preserves the native status flow when the private lookup fails' do
    allow(Ibsoft::ExternalMessaging::Delivery).to receive(:find_by)
      .and_raise(ActiveRecord::ConnectionNotEstablished)
    service = service_class.new(
      inbox: delivery.inbox,
      status: { id: 'wamid.native-message', status: 'delivered' }
    )

    expect { service.call }.not_to raise_error
    expect(service.native_called).to be(true)
  end
end

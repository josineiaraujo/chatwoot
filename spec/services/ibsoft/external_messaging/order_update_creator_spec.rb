require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrderUpdateCreator do
  let(:order) { create(:ibsoft_external_message_order) }
  let(:endpoint) { order.opening_delivery.endpoint }
  let(:command) do
    {
      reference_id: order.reference_id,
      order_status: 'processing',
      payment_status: nil,
      message_content: 'Processing',
      description: 'Processing',
      payment_timestamp: nil
    }
  end

  def create_update
    described_class.new(endpoint: endpoint, command: command).call
  end

  it 'creates a durable queued update in the endpoint tenant' do
    expect { create_update }.to change(Ibsoft::ExternalMessaging::OrderUpdate, :count).by(1)

    expect(create_update.update).to have_attributes(
      endpoint_id: endpoint.id,
      account_id: endpoint.account_id,
      inbox_id: endpoint.inbox_id,
      status: 'queued'
    )
  end

  it 'records the actor and source for a manual update' do
    admin = create(:user, :administrator, account: endpoint.account)
    result = described_class.new(
      endpoint: endpoint,
      command: command,
      requested_by: admin,
      source: 'manual'
    ).call

    expect(result.update).to have_attributes(
      source: 'manual',
      requested_by_id: admin.id
    )
  end

  it 'requires an actor for a manual update' do
    expect do
      described_class.new(
        endpoint: endpoint,
        command: command,
        source: 'manual'
      ).call
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'deduplicates the requested projected state while an update is queued' do
    first = create_update
    second = create_update

    expect(second).to have_attributes(
      update: first.update,
      created: false,
      unchanged: false
    )
  end

  it 'returns unchanged without creating an update for the current state' do
    result = described_class.new(
      endpoint: endpoint,
      command: command.merge(order_status: 'pending')
    ).call

    expect(result).to have_attributes(created: false, unchanged: true, update: nil)
  end

  it 'keeps references isolated by account and inbox' do
    foreign_endpoint = create(:ibsoft_external_message_endpoint)

    expect do
      described_class.new(
        endpoint: foreign_endpoint,
        command: command
      ).call
    end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) { |error|
      expect(error.code).to eq('order_update_not_found')
    }
  end

  it 'keeps IXC order updates isolated by the normalized recipient' do
    expect do
      described_class.new(
        endpoint: endpoint,
        command: command,
        recipient: '5511999999999'
      ).call
    end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) { |error|
      expect(error.code).to eq('order_update_not_found')
    }

    result = described_class.new(
      endpoint: endpoint,
      command: command,
      recipient: order.opening_delivery.recipient
    ).call
    expect(result.created).to be(true)
  end

  it 'blocks new updates when an earlier result is uncertain' do
    create(:ibsoft_external_message_order_update, order: order, status: 'uncertain')

    expect { create_update }.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest) { |error|
      expect(error.code).to eq('order_update_blocked')
    }
  end
end

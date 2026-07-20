require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::RecipientSender do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:other_agent) { create(:user, account: account) }
  let(:sending_agent) { create(:user, account: account) }
  let(:channel) { create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:inbox) { channel.inbox }
  let(:broadcast) do
    create(
      :ibsoft_message_broadcast,
      account: account,
      inbox: inbox,
      created_by: agent,
      sent_by: sending_agent,
      template_name: 'ticket_status_updated',
      template_language: 'en',
      conversation_mode: 'close_after_send',
      template_variables: {
        'name' => { 'type' => 'customer_field', 'field' => 'name', 'component_type' => 'BODY' },
        'ticket_id' => { 'type' => 'fixed', 'value' => '42', 'component_type' => 'BODY' }
      }
    )
  end
  let(:recipient) do
    create(
      :ibsoft_message_broadcast_recipient,
      broadcast: broadcast,
      customer_name: 'Cliente Teste',
      primary_phone: '+5575982479788',
      fallback_phone: nil,
      template_variable_values: { 'name' => 'Cliente Teste' }
    )
  end

  before do
    allow(broadcast.inbox).to receive(:channel).and_return(channel)
    allow(channel).to receive(:send_template).and_return('wamid.123')
  end

  it 'creates a conversation and sends the selected template without calling external APIs in the spec', :aggregate_failures do
    expect do
      described_class.new(broadcast: broadcast, recipient: recipient).call
    end.to change(Message, :count).by(1)

    recipient.reload
    expect(recipient.status).to eq('sent')
    expect(recipient.phone_status).to eq('primary')
    expect(recipient.phone_used).to eq('+5575982479788')
    expect(recipient.conversation).to be_resolved
    expect(recipient.message.sender).to eq(sending_agent)
    expect(recipient.message.source_id).to eq('wamid.123')
    expect(recipient.message.content).to include('Cliente Teste')
  end

  it 'reuses an open conversation for the customer even when assigned to another agent', :aggregate_failures do
    contact = create(:contact, account: account, name: 'Cliente Teste', phone_number: '+5575982479788')
    contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5575982479788')
    existing_conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      assignee: other_agent,
      status: :open
    )

    conversation_count = Conversation.count

    expect do
      described_class.new(broadcast: broadcast, recipient: recipient).call
    end.to change(Message, :count).by(1)

    recipient.reload
    expect(Conversation.count).to eq(conversation_count)
    expect(recipient.conversation).to eq(existing_conversation)
    expect(recipient.message.conversation).to eq(existing_conversation)
    expect(recipient.message.sender).to eq(sending_agent)
    expect(existing_conversation.reload).to be_open
    expect(existing_conversation.assignee).to eq(other_agent)
  end

  it 'does not send an already processed recipient twice', :aggregate_failures do
    sender = described_class.new(broadcast: broadcast, recipient: recipient)

    sender.call

    expect do
      expect(sender.call).to be(false)
    end.not_to change(Message, :count)
    expect(channel).to have_received(:send_template).once
    expect(recipient.reload.status).to eq('sent')
  end

  it 'does not send a recipient claimed by another worker' do
    recipient.update!(status: 'processing')

    expect do
      expect(described_class.new(broadcast: broadcast, recipient: recipient).call).to be(false)
    end.not_to change(Message, :count)
  end
end

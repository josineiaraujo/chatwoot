require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::RecipientSender do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:other_agent) { create(:user, account: account) }
  let(:sending_agent) { create(:user, account: account) }
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:inbox) { channel.inbox }
  let(:broadcast) do
    create(
      :ibsoft_message_broadcast,
      account: account,
      inbox: inbox,
      created_by: agent,
      sent_by: sending_agent,
      dispatch_mode: 'single',
      conversation_mode: 'close_after_send',
      template_name: 'ticket_status_updated',
      template_language: 'en',
      template_variables: {
        'name' => { 'type' => 'customer_field', 'field' => 'name', 'component_type' => 'BODY' }
      }
    )
  end
  let(:recipient) do
    create(
      :ibsoft_message_broadcast_recipient,
      broadcast: broadcast,
      customer_name: 'Cliente Teste',
      primary_phone: '+5575982479788',
      fallback_phone: '+5575999999999',
      template_variable_values: { 'name' => 'Cliente Teste' }
    )
  end
  let(:meta_client) { instance_double(Ibsoft::MessageBroadcast::MetaTemplateClient) }

  before do
    allow(Ibsoft::MessageBroadcast::MetaTemplateClient).to receive(:new).and_return(meta_client)
    allow(meta_client).to receive(:call).and_return(
      Ibsoft::MessageBroadcast::MetaTemplateClient::Result.new(message_id: 'wamid.123', http_status: 200)
    )
  end

  it 'creates a conversation only when conversation delivery is selected', :aggregate_failures do
    expect do
      described_class.new(broadcast: broadcast, recipient: recipient).call
    end.to change(Message, :count).by(1)

    recipient.reload
    expect(recipient.status).to eq('accepted')
    expect(recipient.phone_status).to eq('primary')
    expect(recipient.phone_used).to eq('+5575982479788')
    expect(recipient.meta_message_id).to eq('wamid.123')
    expect(recipient.conversation).to be_resolved
    expect(recipient.message.sender).to eq(sending_agent)
    expect(recipient.message.source_id).to eq('wamid.123')
  end

  it 'sends directly to Meta without creating Chatwoot entities', :aggregate_failures do
    broadcast.update!(conversation_mode: 'direct')

    expect do
      described_class.new(broadcast: broadcast, recipient: recipient).call
    end.not_to(change { [Contact.count, ContactInbox.count, Conversation.count, Message.count] })

    recipient.reload
    expect(recipient).to have_attributes(
      status: 'accepted',
      phone_status: 'primary',
      phone_used: '+5575982479788',
      meta_message_id: 'wamid.123',
      conversation_id: nil,
      message_id: nil
    )
  end

  it 'reuses an open conversation without changing its assignee', :aggregate_failures do
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

    described_class.new(broadcast: broadcast, recipient: recipient).call

    recipient.reload
    expect(Conversation.count).to eq(conversation_count)
    expect(recipient.conversation).to eq(existing_conversation)
    expect(existing_conversation.reload).to be_open
    expect(existing_conversation.assignee).to eq(other_agent)
  end

  it 'uses the fallback only after a confirmed primary rejection', :aggregate_failures do
    rejected = Ibsoft::MessageBroadcast::MetaTemplateClient::RejectedError.new(
      'invalid recipient',
      code: '131026',
      http_status: 400
    )
    fallback_result = Ibsoft::MessageBroadcast::MetaTemplateClient::Result.new(
      message_id: 'wamid.fallback',
      http_status: 200
    )
    allow(meta_client).to receive(:call).and_invoke(
      ->(_phone_candidate) { raise rejected },
      ->(_phone_candidate) { fallback_result }
    )

    described_class.new(broadcast: broadcast, recipient: recipient).call

    expect(meta_client).to have_received(:call).twice
    expect(recipient.reload).to have_attributes(
      status: 'accepted',
      phone_status: 'fallback',
      phone_used: '+5575999999999',
      meta_message_id: 'wamid.fallback'
    )
  end

  it 'does not try the fallback when the primary result is uncertain', :aggregate_failures do
    uncertain = Ibsoft::MessageBroadcast::MetaTemplateClient::UncertainError.new(
      'timeout',
      code: 'delivery_result_uncertain'
    )
    allow(meta_client).to receive(:call).and_raise(uncertain)

    described_class.new(broadcast: broadcast, recipient: recipient).call

    expect(meta_client).to have_received(:call).once
    expect(recipient.reload).to have_attributes(
      status: 'uncertain',
      phone_status: 'primary',
      phone_used: '+5575982479788',
      error_code: 'delivery_result_uncertain'
    )
  end

  it 'does not send an already processed recipient twice', :aggregate_failures do
    sender = described_class.new(broadcast: broadcast, recipient: recipient)

    sender.call

    expect(sender.call).to be(false)
    expect(meta_client).to have_received(:call).once
  end

  it 'does not send a recipient claimed by another worker' do
    recipient.update!(status: 'processing')

    expect(described_class.new(broadcast: broadcast, recipient: recipient).call).to be(false)
    expect(meta_client).not_to have_received(:call)
  end
end

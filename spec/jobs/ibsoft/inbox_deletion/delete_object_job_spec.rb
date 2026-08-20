# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ibsoft inbox deletion integrity', type: :job do
  let!(:account) { create(:account) }
  let!(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let!(:inbox) { Inbox.find_by!(channel: channel) }

  before do
    stub_request(:post, %r{\Ahttps://graph\.facebook\.com/v[\d.]+/123456789\z})
      .with(body: { webhook_configuration: { override_callback_uri: '' } }.to_json)
      .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
    stub_request(:post, %r{\Ahttps://graph\.facebook\.com/v[\d.]+/123456789/deregister\z})
      .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
    stub_request(:delete, %r{\Ahttps://graph\.facebook\.com/v[\d.]+/123456789/subscribed_apps\z})
      .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
  end

  describe 'DeleteObjectJob' do
    it 'deletes distribution and localization records owned by the inbox', :aggregate_failures do
      team = create(:team, account: account)
      distribution_policy = create(:ibsoft_distribution_policy, account: account)
      channel_policy = create(
        :ibsoft_distribution_channel_policy,
        account: account,
        inbox: inbox,
        distribution_policy: distribution_policy
      )
      team_policy = create(
        :ibsoft_distribution_team_policy,
        account: account,
        inbox: inbox,
        team: team,
        distribution_policy: distribution_policy
      )
      handoff_policy = create(
        :ibsoft_automation_handoff_policy,
        account: account,
        inbox: inbox,
        target_team: team
      )
      working_hour_break = create(:ibsoft_working_hour_break, account: account, inbox: inbox)
      conversation = create(:conversation, account: account, inbox: inbox, team: team)
      event_log = create(
        :ibsoft_distribution_event_log,
        account: account,
        inbox: inbox,
        team: team,
        conversation: conversation
      )

      expect { DeleteObjectJob.perform_now(inbox) }.not_to raise_error

      expect(Inbox.exists?(inbox.id)).to be(false)
      expect(Ibsoft::ConversationDistribution::ChannelPolicy.exists?(channel_policy.id)).to be(false)
      expect(Ibsoft::ConversationDistribution::TeamPolicy.exists?(team_policy.id)).to be(false)
      expect(Ibsoft::ConversationDistribution::AutomationHandoffPolicy.exists?(handoff_policy.id)).to be(false)
      expect(Ibsoft::Localization::WorkingHourBreak.exists?(working_hour_break.id)).to be(false)
      expect(event_log.reload.inbox_id).to be_nil
      expect(Ibsoft::ConversationDistribution::Policy.exists?(distribution_policy.id)).to be(true)
    end

    it 'deletes external messaging and broadcast records without blocking conversation cleanup', :aggregate_failures do
      endpoint = create(
        :ibsoft_external_message_endpoint,
        account: account,
        inbox: inbox,
        whatsapp_channel: channel
      )
      order = create(:ibsoft_external_message_order, endpoint: endpoint)
      delivery = order.opening_delivery
      order_update = create(:ibsoft_external_message_order_update, order: order)

      conversation = create(:conversation, account: account, inbox: inbox)
      message = create(:message, account: account, inbox: inbox, conversation: conversation)
      broadcast = create(:ibsoft_message_broadcast, account: account, inbox: inbox)
      recipient = create(
        :ibsoft_message_broadcast_recipient,
        broadcast: broadcast,
        conversation: conversation,
        message: message
      )

      expect { DeleteObjectJob.perform_now(inbox) }.not_to raise_error

      expect(Ibsoft::ExternalMessaging::Endpoint.exists?(endpoint.id)).to be(false)
      expect(Ibsoft::ExternalMessaging::Delivery.exists?(delivery.id)).to be(false)
      expect(Ibsoft::ExternalMessaging::Order.exists?(order.id)).to be(false)
      expect(Ibsoft::ExternalMessaging::OrderUpdate.exists?(order_update.id)).to be(false)
      expect(Ibsoft::MessageBroadcast::Broadcast.exists?(broadcast.id)).to be(false)
      expect(Ibsoft::MessageBroadcast::Recipient.exists?(recipient.id)).to be(false)
      expect(Conversation.exists?(conversation.id)).to be(false)
    end

    it 'keeps private records that belong to another inbox' do
      other_channel = create(
        :channel_whatsapp,
        account: account,
        provider: 'whatsapp_cloud',
        sync_templates: false,
        validate_provider_config: false
      )
      other_inbox = Inbox.find_by!(channel: other_channel)
      other_policy = create(
        :ibsoft_automation_handoff_policy,
        account: account,
        inbox: other_inbox,
        target_team: create(:team, account: account)
      )

      DeleteObjectJob.perform_now(inbox)

      expect(other_inbox.reload).to be_present
      expect(other_policy.reload).to be_present
    end
  end
end

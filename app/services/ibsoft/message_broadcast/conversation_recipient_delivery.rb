class Ibsoft::MessageBroadcast::ConversationRecipientDelivery
  SKIP_AUTO_DELIVERY_SOURCE_PREFIX = 'ibsoft-message-broadcast'.freeze
  Result = Data.define(:meta_message_id, :conversation, :message)

  def initialize(broadcast:, recipient:)
    @broadcast = broadcast
    @recipient = recipient
    @inbox = broadcast.inbox
    @channel = @inbox.channel
  end

  def call(phone_candidate)
    reset_attempt!
    @conversation = find_or_create_conversation(phone_candidate)
    @message = create_message
    result = send_template(phone_candidate)
    message.update!(source_id: result.message_id)
    close_conversation_if_needed

    Result.new(meta_message_id: result.message_id, conversation: conversation, message: message)
  rescue StandardError => e
    mark_message_failed(e)
    close_failed_conversation
    raise
  end

  private

  attr_reader :broadcast, :recipient, :inbox, :channel, :conversation, :message

  def reset_attempt!
    @conversation = nil
    @message = nil
    @reused_open_conversation = false
  end

  def find_or_create_conversation(phone_candidate)
    contact_inbox = find_or_create_contact_inbox(phone_candidate)
    existing_conversation = existing_open_conversation(contact_inbox)
    if existing_conversation
      @reused_open_conversation = true
      return prepare_reused_conversation(existing_conversation)
    end

    create_conversation(contact_inbox)
  end

  def existing_open_conversation(contact_inbox)
    Conversation.open
                .where(account: broadcast.account, inbox: inbox, contact: contact_inbox.contact)
                .reorder(last_activity_at: :desc, id: :desc)
                .first
  end

  def create_conversation(contact_inbox)
    Conversation.transaction do
      created_conversation = Conversation.create!(
        account: broadcast.account,
        inbox: inbox,
        contact: contact_inbox.contact,
        contact_inbox: contact_inbox,
        assignee: new_conversation_assignee,
        team: broadcast.team,
        status: :open,
        additional_attributes: { 'ibsoft_message_broadcast_id' => broadcast.id }
      )
      created_conversation.open! if keep_open? && !created_conversation.open?
      created_conversation
    end
  end

  def prepare_reused_conversation(existing_conversation)
    existing_conversation.update!(assignee: sending_agent) if keep_open? && existing_conversation.assignee_id.blank?
    add_sending_agent_as_participant(existing_conversation)
    existing_conversation
  end

  def add_sending_agent_as_participant(existing_conversation)
    return if existing_conversation.assignee_id.blank? || existing_conversation.assignee_id == sending_agent.id

    existing_conversation.conversation_participants.find_or_create_by!(user: sending_agent)
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def new_conversation_assignee
    keep_open? ? sending_agent : broadcast.assignee
  end

  def keep_open?
    broadcast.conversation_mode == 'keep_open'
  end

  def sending_agent
    @sending_agent ||= broadcast.sent_by || broadcast.created_by
  end

  def find_or_create_contact_inbox(phone_candidate)
    ContactInboxWithContactBuilder.new(
      inbox: inbox,
      source_id: phone_candidate.source_id,
      contact_attributes: {
        identifier: contact_identifier,
        name: recipient.customer_name,
        phone_number: phone_candidate.phone_number
      }
    ).perform
  end

  def contact_identifier
    "ibsoft-erp-#{broadcast.erp_connection.provider}-#{recipient.external_customer_id}"
  end

  def create_message
    Messages::MessageBuilder.new(
      sending_agent,
      conversation,
      message_params
    ).perform
  end

  def message_params
    {
      message_type: 'outgoing',
      content: rendered_content,
      content_type: 'text',
      content_attributes: { automation_rule_id: "ibsoft_message_broadcast_#{broadcast.id}" },
      source_id: "#{SKIP_AUTO_DELIVERY_SOURCE_PREFIX}-#{recipient.id}-#{SecureRandom.hex(6)}",
      template_params: template_params
    }
  end

  def template_params
    @template_params ||= Ibsoft::MessageBroadcast::TemplateParameterBuilder.new(
      broadcast: broadcast,
      recipient: recipient
    ).call
  end

  def rendered_content
    Ibsoft::MessageBroadcast::TemplateContentRenderer.new(
      channel: channel,
      template_params: template_params
    ).call.presence || broadcast.template_name
  end

  def send_template(phone_candidate)
    Ibsoft::MessageBroadcast::MetaTemplateClient.new(
      broadcast: broadcast,
      recipient: recipient,
      message: message
    ).call(phone_candidate)
  end

  def close_conversation_if_needed
    conversation.resolved! if broadcast.conversation_mode == 'close_after_send' && !@reused_open_conversation
  end

  def close_failed_conversation
    conversation&.resolved! unless @reused_open_conversation
  end

  def mark_message_failed(error)
    return if message.blank?

    message.update(
      status: :failed,
      content_attributes: (message.content_attributes || {}).merge(external_error: error.message)
    )
  end
end

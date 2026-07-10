class Ibsoft::MessageBroadcast::RecipientSender
  SKIP_AUTO_DELIVERY_SOURCE_PREFIX = 'ibsoft-message-broadcast'.freeze

  def initialize(broadcast:, recipient:)
    @broadcast = broadcast
    @recipient = recipient
    @inbox = broadcast.inbox
    @channel = @inbox.channel
    @reused_open_conversation = false
  end

  def call
    return skip_without_phone! if candidate_phones.blank?

    candidate_phones.each do |phone_candidate|
      return mark_sent!(phone_candidate) if send_to_phone(phone_candidate)
    end

    fail_without_delivery!
  end

  private

  attr_reader :broadcast, :recipient, :inbox, :channel, :conversation, :message

  def candidate_phones
    @candidate_phones ||= [
      phone_candidate('primary', recipient.primary_phone),
      phone_candidate('fallback', recipient.fallback_phone)
    ].compact_blank.uniq { |candidate| candidate[:source_id] }
  end

  def phone_candidate(kind, phone)
    source_id = normalized_source_id(phone)
    return if source_id.blank?

    { kind: kind, phone_number: "+#{source_id}", source_id: source_id }
  end

  def normalized_source_id(phone)
    phone.to_s.gsub(/\D+/, '').presence
  end

  def send_to_phone(phone_candidate)
    @conversation = find_or_create_conversation(phone_candidate)
    @message = create_message
    message_id = send_template_message(phone_candidate)
    return false if message_id.blank?

    message.update!(source_id: message_id)
    close_conversation_if_needed
    true
  rescue StandardError => e
    mark_message_failed(e)
    close_failed_conversation
    false
  end

  def find_or_create_conversation(phone_candidate)
    contact_inbox = find_or_create_contact_inbox(phone_candidate)
    existing_conversation = existing_open_conversation(contact_inbox)
    if existing_conversation
      @reused_open_conversation = true
      return existing_conversation
    end

    @reused_open_conversation = false
    create_conversation(contact_inbox)
  end

  def existing_open_conversation(contact_inbox)
    Conversation.open
                .where(account: broadcast.account, inbox: inbox, contact: contact_inbox.contact)
                .reorder(last_activity_at: :desc, id: :desc)
                .first
  end

  def create_conversation(contact_inbox)
    Conversation.create!(
      account: broadcast.account,
      inbox: inbox,
      contact: contact_inbox.contact,
      contact_inbox: contact_inbox,
      assignee: broadcast.assignee,
      team: broadcast.team,
      status: :open,
      additional_attributes: { 'ibsoft_message_broadcast_id' => broadcast.id }
    )
  end

  def find_or_create_contact_inbox(phone_candidate)
    ContactInboxWithContactBuilder.new(
      inbox: inbox,
      source_id: phone_candidate[:source_id],
      contact_attributes: {
        identifier: contact_identifier,
        name: recipient.customer_name,
        phone_number: phone_candidate[:phone_number]
      }
    ).perform
  end

  def contact_identifier
    "ibsoft-erp-#{broadcast.erp_connection.provider}-#{recipient.external_customer_id}"
  end

  def create_message
    Messages::MessageBuilder.new(
      broadcast.sent_by || broadcast.created_by,
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

  def send_template_message(phone_candidate)
    name, namespace, lang_code, processed_parameters = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: template_params,
      message: message
    ).call

    raise I18n.t('ibsoft.message_broadcast.errors.template_not_found') if name.blank?

    channel.send_template(
      phone_candidate[:source_id],
      {
        name: name,
        namespace: namespace,
        lang_code: lang_code,
        parameters: processed_parameters
      },
      message
    )
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

  def mark_sent!(phone_candidate)
    recipient.update!(
      status: 'sent',
      phone_status: phone_candidate[:kind],
      phone_used: phone_candidate[:phone_number],
      conversation: conversation,
      message: message,
      error_code: nil,
      error_message: nil
    )
  end

  def skip_without_phone!
    recipient.update!(
      status: 'skipped',
      phone_status: 'unavailable',
      error_code: 'without_valid_phone',
      error_message: nil
    )
  end

  def fail_without_delivery!
    recipient.update!(
      status: 'failed',
      phone_status: 'invalid',
      error_code: 'delivery_failed',
      error_message: message&.external_error.presence || message&.content_attributes&.dig('external_error')
    )
  end
end

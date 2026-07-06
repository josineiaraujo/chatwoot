require 'digest'

class Ibsoft::ConversationDistribution::AssignmentConfirmationNotifier
  RECORDS_KEY = 'ibsoft_distribution_assignment_confirmation_records'.freeze

  def initialize(conversation:, assignee:)
    @conversation = conversation
    @assignee = assignee
  end

  def perform
    return result(false, 'disabled') unless enabled?
    return result(false, 'blank_message') if message_content.blank?
    return result(false, 'first_reply_already_exists') if first_reply_blocked?
    return result(false, 'already_applied') unless reserve_record

    message = create_message
    persist_record(result(true, 'message_sent', message_id: message.id))
  rescue StandardError
    remove_record
    raise
  end

  private

  attr_reader :conversation, :assignee

  def create_message
    Messages::MessageBuilder.new(nil, conversation, message_params).perform
  end

  def message_params
    {
      content: message_content,
      private: false,
      message_type: :template,
      content_attributes: {
        ibsoft_conversation_distribution: {
          action: 'assignment_confirmation',
          assignee_id: assignee.id,
          assignee_name: assignee.name
        }
      }
    }
  end

  def enabled?
    ActiveModel::Type::Boolean.new.cast(config['enabled'])
  end

  def first_reply_blocked?
    ActiveModel::Type::Boolean.new.cast(config.fetch('only_before_first_reply', true)) &&
      conversation.first_reply_created_at.present?
  end

  def message_content
    @message_content ||= render_message(config['message'].to_s).strip
  end

  def render_message(template)
    template
      .gsub('{{agent.name}}', assignee.name.to_s)
      .gsub('{{agent.email}}', assignee.email.to_s)
      .gsub('{{team.name}}', conversation.team&.name.to_s)
      .gsub('{{account.name}}', conversation.account.name.to_s)
  end

  def config
    @config ||= policy_config.fetch('assignment_confirmation', {})
  end

  def policy_config
    effective_policy[:config] || {}
  end

  def effective_policy
    @effective_policy ||= Ibsoft::ConversationDistribution::EffectivePolicyResolver.new(
      account: conversation.account,
      inbox: conversation.inbox,
      team: conversation.team
    ).perform
  end

  def reserve_record
    reserved = false
    with_reloaded_lock do
      next if records.key?(record_key)

      write_record(result(false, 'processing'))
      reserved = true
    end
    reserved
  end

  def persist_record(action_result)
    with_reloaded_lock { write_record(action_result) }
    action_result
  end

  def remove_record
    with_reloaded_lock do
      records_payload = records
      records_payload.delete(record_key)
      conversation.update!(additional_attributes: attributes.merge(RECORDS_KEY => records_payload))
    end
  end

  def write_record(action_result)
    conversation.update!(
      additional_attributes: attributes.merge(
        RECORDS_KEY => records.merge(
          record_key => {
            applied: action_result[:applied],
            status: action_result[:status],
            message_id: action_result[:message_id],
            assignee_id: assignee.id,
            recorded_at: Time.current.iso8601
          }.compact
        )
      )
    )
  end

  def record_key
    @record_key ||= [
      effective_policy[:id],
      assignee.id,
      Digest::SHA256.hexdigest(message_content)
    ].join(':')
  end

  def records
    attributes.fetch(RECORDS_KEY, {}).to_h
  end

  def attributes
    (conversation.additional_attributes || {}).deep_dup
  end

  def with_reloaded_lock(&)
    conversation.reload
    conversation.with_lock(&)
  end

  def result(applied, status, metadata = {})
    { applied: applied, status: status }.merge(metadata)
  end
end

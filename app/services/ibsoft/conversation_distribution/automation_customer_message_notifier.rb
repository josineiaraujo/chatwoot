class Ibsoft::ConversationDistribution::AutomationCustomerMessageNotifier
  PHASE_FORWARD = :forward
  PHASE_CLOSE_WARNING = :close_warning
  PHASE_CLOSE_FINAL = :close_final
  PHASES = [PHASE_FORWARD, PHASE_CLOSE_WARNING, PHASE_CLOSE_FINAL].freeze
  ACTION_BY_PHASE = {
    PHASE_FORWARD => Ibsoft::ConversationDistribution::AutomationHandoffPolicy::ACTION_FORWARD_TO_TEAM,
    PHASE_CLOSE_WARNING => 'close_warning',
    PHASE_CLOSE_FINAL => Ibsoft::ConversationDistribution::AutomationHandoffPolicy::ACTION_CLOSE_CONVERSATION
  }.freeze

  def initialize(conversation:, policy:, phase:)
    @conversation = conversation
    @policy = policy
    @phase = phase.to_sym
  end

  def perform
    perform!
  rescue StandardError => e
    Rails.logger.error(
      '[Ibsoft::ConversationDistribution] automation customer message failed ' \
      "(#{phase}): #{e.class} - #{e.message}"
    )
    result(false, 'error', error: e.class.name)
  end

  def perform!
    raise ArgumentError, "unknown automation message phase: #{phase}" unless PHASES.include?(phase)
    return result(false, 'disabled') unless enabled?
    return result(false, 'blank_message') if content.blank?

    message = Messages::MessageBuilder.new(nil, conversation, message_params).perform
    result(true, 'message_sent', message_id: message.id)
  end

  private

  attr_reader :conversation, :policy, :phase

  def enabled?
    case phase
    when PHASE_FORWARD
      policy.customer_message_enabled?
    when PHASE_CLOSE_WARNING
      policy.close_warning_enabled?
    when PHASE_CLOSE_FINAL
      policy.close_final_message_enabled?
    end
  end

  def content
    @content ||= configured_content.presence || default_content
  end

  def configured_content
    case phase
    when PHASE_FORWARD
      policy.customer_message
    when PHASE_CLOSE_WARNING
      policy.close_warning_message
    when PHASE_CLOSE_FINAL
      policy.close_final_message
    end
  end

  def default_content
    return close_warning_default if phase == PHASE_CLOSE_WARNING
    return close_final_default if phase == PHASE_CLOSE_FINAL

    nil
  end

  def close_warning_default
    I18n.t(
      'ibsoft.conversation_distribution.automation_close.warning_default',
      locale: locale,
      count: policy.close_warning_delay_minutes
    )
  end

  def close_final_default
    I18n.t(
      'ibsoft.conversation_distribution.automation_close.final_default',
      locale: locale
    )
  end

  def locale
    conversation.account&.locale.presence || I18n.default_locale
  end

  def message_params
    {
      content: content,
      private: false,
      message_type: :template,
      content_attributes: {
        ibsoft_conversation_distribution: {
          action: ACTION_BY_PHASE.fetch(phase),
          reason: Ibsoft::ConversationDistribution::AutomationHandoffExecutor::REASON_STALLED,
          target_team_id: policy.target_team_id
        }
      }
    }
  end

  def result(applied, status, metadata = {})
    { applied: applied, status: status }.merge(metadata)
  end
end

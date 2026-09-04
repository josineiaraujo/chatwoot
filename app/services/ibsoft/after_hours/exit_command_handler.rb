class Ibsoft::AfterHours::ExitCommandHandler
  def initialize(message:)
    @message = message
  end

  def perform
    return false unless eligible_message?

    wait = active_wait
    return false unless command_matches?(wait)

    handle_wait(wait)
  end

  private

  attr_reader :message

  def eligible_message?
    message.present? && message.incoming? && !message.private?
  end

  def active_wait
    Ibsoft::AfterHours::Wait.active.includes(:after_hours_policy).find_by(
      account_id: message.account_id,
      conversation_id: message.conversation_id
    )
  end

  def handle_wait(wait)
    handled = false
    message.conversation.reload
    message.conversation.with_lock do
      wait.reload
      next unless active_wait_eligible?(wait)

      finish_wait(wait)
      handled = true
    end
    handled
  end

  def finish_wait(wait)
    confirmation = Messages::MessageBuilder.new(nil, message.conversation, confirmation_message_params(wait)).perform
    wait.update!(status: 'exited', exit_message: confirmation, finished_at: Time.current)
    Ibsoft::ConversationOwnership::Clearer.perform(message.conversation)
    message.conversation.update!(status: :resolved)
  end

  def command_matches?(wait)
    wait.present? && normalized_content == wait.exit_command
  end

  def normalized_content
    @normalized_content ||= message.content.to_s.squish.downcase
  end

  def active_wait_eligible?(wait)
    wait.active? &&
      message.created_at >= wait.started_at &&
      message.conversation.open? &&
      message.conversation.assignee.blank? &&
      message.conversation.team_id == wait.team_id
  end

  def confirmation_message_params(wait)
    {
      content: wait.exit_confirmation_message,
      private: false,
      content_attributes: {
        Ibsoft::AfterHours::WaitStarter::CONTENT_ATTRIBUTE_KEY => {
          event: 'wait_exited',
          policy_id: wait.after_hours_policy_id
        }
      }
    }
  end
end

module Ibsoft::AfterHours::AgentBotListenerExtension
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return if Ibsoft::AfterHours::ExitCommandHandler.new(message: message).perform

    super
  end

  def conversation_resolved(event)
    reconcile_wait(event)
    super
  end

  def conversation_status_changed(event)
    reconcile_wait(event)
    super
  end

  def conversation_updated(event)
    reconcile_wait(event)
    super
  end

  private

  def reconcile_wait(event)
    conversation = extract_conversation_and_account(event)[0]
    return if conversation.blank?

    Ibsoft::AfterHours::WaitReconciler.new(conversation: conversation).perform
  end
end

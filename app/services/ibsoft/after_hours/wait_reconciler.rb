class Ibsoft::AfterHours::WaitReconciler
  def initialize(conversation:)
    @conversation = conversation
  end

  def perform
    wait = Ibsoft::AfterHours::Wait.find_by(
      conversation_id: conversation.id,
      account_id: conversation.account_id
    )
    return if wait.blank?

    wait.with_lock do
      wait.reload
      next unless wait.active?

      conversation.reload
      next if still_waiting?(wait)

      wait.update!(status: 'cancelled', finished_at: Time.current)
      wait
    end
  end

  private

  attr_reader :conversation

  def still_waiting?(wait)
    conversation.open? && conversation.assignee.blank? && conversation.team_id == wait.team_id
  end
end

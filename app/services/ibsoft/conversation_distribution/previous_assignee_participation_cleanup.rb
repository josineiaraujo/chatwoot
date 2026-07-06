class Ibsoft::ConversationDistribution::PreviousAssigneeParticipationCleanup
  def initialize(account:, conversation:, previous_assignee:, new_assignee: nil)
    @account = account
    @conversation = conversation
    @previous_assignee = previous_assignee
    @new_assignee = new_assignee
  end

  def perform
    return empty_result if previous_assignee.blank?
    return empty_result if previous_assignee.id == new_assignee&.id

    removed_count = stale_participants.count
    stale_participants.find_each(&:destroy!)

    { removed_count: removed_count }
  rescue StandardError => e
    Rails.logger.warn(
      '[Ibsoft::ConversationDistribution] previous assignee participation cleanup failed ' \
      "conversation=#{conversation&.id} previous_assignee=#{previous_assignee&.id} error=#{e.class}: #{e.message}"
    )

    empty_result.merge(error: e.class.name)
  end

  private

  attr_reader :account, :conversation, :previous_assignee, :new_assignee

  def stale_participants
    @stale_participants ||= ConversationParticipant.where(
      account: account,
      conversation: conversation,
      user: previous_assignee
    )
  end

  def empty_result
    { removed_count: 0 }
  end
end

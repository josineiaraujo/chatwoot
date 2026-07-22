class Ibsoft::ConversationDistribution::ManualTransferPermission
  def initialize(conversation:, actor:)
    @conversation = conversation
    @actor = actor
  end

  def allowed?
    return false if account_user.blank?

    conversation.assignee_id.blank? || conversation.assignee_id == actor.id || account_user.administrator?
  end

  private

  attr_reader :conversation, :actor

  def account_user
    @account_user ||= actor.account_users.find_by(account_id: conversation.account_id)
  end
end

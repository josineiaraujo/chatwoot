module Ibsoft::AccessControl::ConversationPolicy
  def show?
    return false unless super
    return true unless Ibsoft::AccessControl::PermissionResolver.role_assigned?(account_user)

    conversation_manage? || unassigned_manage? || participating_manage?
  end

  private

  def conversation_permissions
    @conversation_permissions ||= Ibsoft::AccessControl::PermissionResolver.permissions_for(account_user)
  end

  def conversation_manage?
    conversation_permissions.include?('conversation_manage')
  end

  def unassigned_manage?
    return false unless conversation_permissions.include?('conversation_unassigned_manage')

    ibsoft_queue_visible_conversation? || assigned_to_user?
  end

  def participating_manage?
    return false unless conversation_permissions.include?('conversation_participating_manage')

    assigned_to_user? || participant?
  end

  def ibsoft_queue_visible_conversation?
    record.assignee_id.nil?
  end
end

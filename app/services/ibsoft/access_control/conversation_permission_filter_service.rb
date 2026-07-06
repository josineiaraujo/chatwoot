module Ibsoft::AccessControl::ConversationPermissionFilterService
  def perform
    return filter_by_ibsoft_permissions if ibsoft_access_profile?

    super
  end

  private

  def ibsoft_access_profile?
    user_role == 'agent' && Ibsoft::AccessControl::PermissionResolver.role_assigned?(account_user)
  end

  def ibsoft_permissions
    Ibsoft::AccessControl::PermissionResolver.permissions_for(account_user)
  end

  def filter_by_ibsoft_permissions
    return accessible_conversations if ibsoft_permissions.include?('conversation_manage')
    return filter_ibsoft_unassigned_and_mine if ibsoft_permissions.include?('conversation_unassigned_manage')
    return accessible_conversations.assigned_to(user) if ibsoft_permissions.include?('conversation_participating_manage')

    Conversation.none
  end

  def filter_ibsoft_unassigned_and_mine
    accessible_conversations.where(assignee_id: [nil, user.id])
  end
end

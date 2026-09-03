Rails.application.config.to_prepare do
  {
    'ConversationPolicy' => Ibsoft::AccessControl::ConversationPolicy,
    'ContactPolicy' => Ibsoft::AccessControl::ContactPolicy,
    'ReportPolicy' => Ibsoft::AccessControl::ReportPolicy,
    'PortalPolicy' => Ibsoft::AccessControl::KnowledgeBasePolicy,
    'ArticlePolicy' => Ibsoft::AccessControl::KnowledgeBasePolicy,
    'CategoryPolicy' => Ibsoft::AccessControl::KnowledgeBasePolicy,
    'Conversations::PermissionFilterService' => Ibsoft::AccessControl::ConversationPermissionFilterService,
    'Conversations::UnreadCounts::Counter' => Ibsoft::AccessControl::UnreadCountsCounter
  }.each do |policy_name, extension|
    policy = policy_name.safe_constantize
    next if policy.blank? || policy.ancestors.include?(extension)

    policy.prepend(extension)
  end
end

Rails.autoloaders.main.on_load('AccountUser') do |account_user|
  extension = Ibsoft::AccessControl::AccountUserPermissions
  account_user.prepend(extension) unless account_user.ancestors.include?(extension)
end

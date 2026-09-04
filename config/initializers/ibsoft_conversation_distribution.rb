Rails.autoloaders.main.on_load('ActionService') do |action_service|
  extension = Ibsoft::ConversationDistribution::ActionServiceExtension
  action_service.prepend(extension) unless action_service.ancestors.include?(extension)
end

Rails.autoloaders.main.on_load('Conversation') do |conversation|
  extension = Ibsoft::ConversationDistribution::TeamAssignmentSourceMarker
  conversation.include(extension) unless conversation.ancestors.include?(extension)
end

conversation = @result[:conversation]

json.conversation_id conversation.display_id
json.status conversation.status
json.snoozed_until conversation.snoozed_until
json.distribution_enqueued @result[:distribution_enqueued]
json.queue_returned @result[:queue_returned]

if conversation.assignee.present?
  json.assignee do
    json.partial! 'api/v1/models/agent', formats: [:json], resource: conversation.assignee
  end
  json.assignee_type 'User'
else
  json.assignee nil
  json.assignee_type nil
end

if conversation.team.present?
  json.team do
    json.partial! 'api/v1/models/team', formats: [:json], resource: conversation.team
  end
else
  json.team nil
end
